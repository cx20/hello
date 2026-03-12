/*
 * hello.c - NES (Famicom) Emulator in a single C file
 *
 * Features:
 *   - MOS 6502 CPU (all official instructions)
 *   - PPU with background + sprite rendering
 *   - Mapper 0 (NROM) and Mapper 66 (GxROM)
 *   - DirectX 12 rendering (dynamic texture + fullscreen quad)
 *   - Player 1 keyboard input
 *
 * Build (MSVC):
 *   cl /O2 /W3 /D_CRT_SECURE_NO_WARNINGS hello.c /link user32.lib gdi32.lib d3d12.lib dxgi.lib d3dcompiler.lib dxguid.lib
 *
 * Usage:
 *   hello.exe game.nes
 */

/* ================================================================
 * Includes
 * ================================================================ */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    float x, y, z;
    float u, v;
} QuadVertex;

/* ================================================================
 * Constants
 * ================================================================ */
#define NES_WIDTH      256
#define NES_HEIGHT     240
#define SCREEN_SCALE   2
#define WINDOW_WIDTH   (NES_WIDTH  * SCREEN_SCALE)
#define WINDOW_HEIGHT  (NES_HEIGHT * SCREEN_SCALE)
#define RENDER_FRAMES  2

/* 6502 status flags */
#define FLAG_C 0x01
#define FLAG_Z 0x02
#define FLAG_I 0x04
#define FLAG_D 0x08
#define FLAG_B 0x10
#define FLAG_U 0x20
#define FLAG_V 0x40
#define FLAG_N 0x80

/* PPU control ($2000) */
#define PPUCTRL_NAMETABLE  0x03
#define PPUCTRL_VRAM_INC   0x04
#define PPUCTRL_SPR_ADDR   0x08
#define PPUCTRL_BG_ADDR    0x10
#define PPUCTRL_SPR_SIZE   0x20
#define PPUCTRL_NMI_ENABLE 0x80

/* PPU mask ($2001) */
#define PPUMASK_BG_LEFT    0x02
#define PPUMASK_SPR_LEFT   0x04
#define PPUMASK_BG_ENABLE  0x08
#define PPUMASK_SPR_ENABLE 0x10

/* PPU status ($2002) */
#define PPUSTAT_OVERFLOW   0x20
#define PPUSTAT_SPR0_HIT   0x40
#define PPUSTAT_VBLANK     0x80

/* Mirroring modes */
#define MIRROR_HORIZONTAL  0
#define MIRROR_VERTICAL    1
#define MIRROR_SINGLE_LO   2
#define MIRROR_SINGLE_HI   3
#define MIRROR_FOUR_SCREEN 4

/* Supported mappers */
#define MAPPER_NROM        0
#define MAPPER_GXROM       66

/* ================================================================
 * Type definitions
 * ================================================================ */

/* Addressing modes */
typedef enum {
    AM_IMP, AM_ACC, AM_IMM, AM_ZPG, AM_ZPX, AM_ZPY,
    AM_REL, AM_ABS, AM_ABX, AM_ABY, AM_IND, AM_IZX, AM_IZY
} AddrMode;

/* Instruction types */
typedef enum {
    INS_ADC, INS_AND, INS_ASL, INS_BCC, INS_BCS, INS_BEQ, INS_BIT, INS_BMI,
    INS_BNE, INS_BPL, INS_BRK, INS_BVC, INS_BVS, INS_CLC, INS_CLD, INS_CLI,
    INS_CLV, INS_CMP, INS_CPX, INS_CPY, INS_DEC, INS_DEX, INS_DEY, INS_EOR,
    INS_INC, INS_INX, INS_INY, INS_JMP, INS_JSR, INS_LDA, INS_LDX, INS_LDY,
    INS_LSR, INS_NOP, INS_ORA, INS_PHA, INS_PHP, INS_PLA, INS_PLP, INS_ROL,
    INS_ROR, INS_RTI, INS_RTS, INS_SBC, INS_SEC, INS_SED, INS_SEI, INS_STA,
    INS_STX, INS_STY, INS_TAX, INS_TAY, INS_TSX, INS_TXA, INS_TXS, INS_TYA,
    INS_XXX
} InsType;

typedef struct {
    uint8_t ins, mode, cycles, page_penalty;
} OpcodeEntry;

typedef struct {
    uint8_t  a, x, y, sp;
    uint16_t pc;
    uint8_t  p;
    uint64_t cycles;
    int      stall;
    uint8_t  nmi_pending;
    uint8_t  irq_pending;
} CPU;

typedef struct {
    uint8_t  ctrl, mask, status, oam_addr;
    uint16_t v, t;
    uint8_t  fine_x, w, data_buf;
    uint8_t  oam[256];
    uint8_t  vram[0x800];
    uint8_t  palette[32];
    int      scanline, cycle, frame_count;
    uint8_t  frame_ready;
    uint8_t  nmi_occurred, nmi_output;
    uint32_t framebuffer[NES_WIDTH * NES_HEIGHT];
} PPU;

typedef struct Cartridge {
    uint8_t *prg_rom;
    uint8_t *chr_rom;
    uint32_t prg_size, chr_size;
    uint8_t  prg_banks, chr_banks;
    uint8_t  mapper, mirror;
    uint8_t  prg_bank_select, chr_bank_select;
    uint8_t  chr_ram[0x2000];
    uint8_t  has_chr_ram;
} Cartridge;

typedef struct Bus {
    CPU       cpu;
    PPU       ppu;
    Cartridge *cart;
    uint8_t   ram[0x800];
    uint8_t   controller[2];
    uint8_t   controller_latch[2];
    uint8_t   controller_strobe;
    uint8_t   dma_page, dma_addr, dma_data;
    uint8_t   dma_transfer, dma_dummy;
    uint64_t  system_cycles;
} Bus;

typedef struct {
    ID3D12Device               *device;
    IDXGISwapChain3            *swap_chain;
    ID3D12CommandQueue         *command_queue;
    ID3D12GraphicsCommandList  *command_list;
    ID3D12CommandAllocator     *command_allocator[RENDER_FRAMES];
    ID3D12DescriptorHeap       *rtv_heap;
    ID3D12DescriptorHeap       *srv_heap;
    ID3D12Resource             *render_targets[RENDER_FRAMES];
    ID3D12RootSignature        *root_signature;
    ID3D12PipelineState        *pipeline_state;
    ID3D12Resource             *vertex_buffer;
    ID3D12Resource             *texture;
    ID3D12Resource             *texture_upload;
    ID3D12Fence                *fence;
    HANDLE                      fence_event;
    UINT64                      fence_value[RENDER_FRAMES];
    UINT                        frame_index;
    UINT                        rtv_descriptor_size;
    UINT                        texture_row_pitch;
    D3D12_VERTEX_BUFFER_VIEW    vertex_buffer_view;
    D3D12_VIEWPORT              viewport;
    D3D12_RECT                  scissor_rect;
    int                         texture_initialized;
} Renderer;

/* ================================================================
 * Forward declarations
 * ================================================================ */
static uint8_t bus_cpu_read(Bus *bus, uint16_t addr);
static void    bus_cpu_write(Bus *bus, uint16_t addr, uint8_t val);
static void    ppu_step(PPU *ppu, Bus *bus);

/* ================================================================
 * Cartridge - iNES ROM loader, Mapper 0 / 66
 * ================================================================ */
typedef struct {
    uint8_t magic[4];
    uint8_t prg_count, chr_count;
    uint8_t flags6, flags7, prg_ram, flags9, flags10;
    uint8_t padding[5];
} iNESHeader;

static int cartridge_load(Cartridge *cart, const char *filename) {
    FILE *fp;
    iNESHeader hdr;
    memset(cart, 0, sizeof(Cartridge));

    fp = fopen(filename, "rb");
    if (!fp) { fprintf(stderr, "Error: Cannot open '%s'\n", filename); return 0; }
    if (fread(&hdr, sizeof(hdr), 1, fp) != 1) { fclose(fp); return 0; }
    if (hdr.magic[0]!='N'||hdr.magic[1]!='E'||hdr.magic[2]!='S'||hdr.magic[3]!=0x1A) {
        fprintf(stderr, "Error: Invalid iNES file\n"); fclose(fp); return 0;
    }

    cart->mapper = (hdr.flags7 & 0xF0) | (hdr.flags6 >> 4);
    if (cart->mapper != MAPPER_NROM && cart->mapper != MAPPER_GXROM) {
        fprintf(stderr, "Error: Only Mapper 0 and 66 supported (got %d)\n", cart->mapper);
        fclose(fp); return 0;
    }

    cart->mirror = (hdr.flags6 & 0x08) ? MIRROR_FOUR_SCREEN
                 : (hdr.flags6 & 0x01) ? MIRROR_VERTICAL : MIRROR_HORIZONTAL;
    if (hdr.flags6 & 0x04) fseek(fp, 512, SEEK_CUR); /* Skip trainer */

    cart->prg_banks = hdr.prg_count;
    cart->prg_size  = (uint32_t)hdr.prg_count * 16384;
    cart->prg_rom   = (uint8_t *)malloc(cart->prg_size);
    if (!cart->prg_rom || fread(cart->prg_rom, cart->prg_size, 1, fp) != 1) {
        fclose(fp); free(cart->prg_rom); return 0;
    }

    cart->chr_banks = hdr.chr_count;
    if (hdr.chr_count > 0) {
        cart->chr_size = (uint32_t)hdr.chr_count * 8192;
        cart->chr_rom  = (uint8_t *)malloc(cart->chr_size);
        if (!cart->chr_rom || fread(cart->chr_rom, cart->chr_size, 1, fp) != 1) {
            fclose(fp); free(cart->prg_rom); free(cart->chr_rom); return 0;
        }
    } else {
        cart->chr_rom = cart->chr_ram;
        cart->chr_size = 0x2000;
        cart->has_chr_ram = 1;
    }

    fclose(fp);
    printf("ROM: PRG=%dKB CHR=%dKB Mapper=%d Mirror=%d\n",
           cart->prg_size/1024, cart->chr_size/1024, cart->mapper, cart->mirror);
    return 1;
}

static uint32_t cartridge_prg_addr(const Cartridge *cart, uint16_t addr) {
    switch (cart->mapper) {
    case MAPPER_GXROM: {
        uint32_t bank_count = cart->prg_size / 0x8000;
        uint32_t bank = bank_count ? (cart->prg_bank_select % bank_count) : 0;
        return bank * 0x8000 + (uint32_t)(addr - 0x8000);
    }
    case MAPPER_NROM:
    default: {
        uint32_t mapped = addr - 0x8000;
        if (cart->prg_banks == 1) mapped &= 0x3FFF;
        return mapped;
    }
    }
}

static uint32_t cartridge_chr_addr(const Cartridge *cart, uint16_t addr) {
    switch (cart->mapper) {
    case MAPPER_GXROM: {
        uint32_t bank_count = cart->chr_size / 0x2000;
        uint32_t bank = bank_count ? (cart->chr_bank_select % bank_count) : 0;
        return bank * 0x2000 + (uint32_t)addr;
    }
    case MAPPER_NROM:
    default:
        return addr;
    }
}

static void cartridge_free(Cartridge *cart) {
    if (cart->prg_rom) free(cart->prg_rom);
    if (cart->chr_rom && !cart->has_chr_ram) free(cart->chr_rom);
}

static uint8_t cartridge_cpu_read(Cartridge *cart, uint16_t addr) {
    if (addr >= 0x8000) {
        uint32_t m = cartridge_prg_addr(cart, addr);
        return cart->prg_rom[m];
    }
    return 0;
}

static void cartridge_cpu_write(Cartridge *c, uint16_t a, uint8_t v) {
    if (c->mapper == MAPPER_GXROM && a >= 0x8000) {
        /* GNROM boards have bus conflicts, so the ROM data can mask the write. */
        uint8_t latch = v & cartridge_cpu_read(c, a);
        c->chr_bank_select = latch & 0x03;
        c->prg_bank_select = (latch >> 4) & 0x03;
    }
}

static uint8_t cartridge_ppu_read(Cartridge *cart, uint16_t addr) {
    return (addr < 0x2000) ? cart->chr_rom[cartridge_chr_addr(cart, addr)] : 0;
}

static void cartridge_ppu_write(Cartridge *cart, uint16_t addr, uint8_t val) {
    if (addr < 0x2000 && cart->has_chr_ram) {
        cart->chr_ram[cartridge_chr_addr(cart, addr)] = val;
    }
}

/* ================================================================
 * PPU - Picture Processing Unit
 * ================================================================ */
static const uint32_t nes_palette[64] = {
    0xFF666666,0xFF002A88,0xFF1412A7,0xFF3B00A4,0xFF5C007E,0xFF6E0040,0xFF6C0600,0xFF561D00,
    0xFF333500,0xFF0B4800,0xFF005200,0xFF004F08,0xFF00404D,0xFF000000,0xFF000000,0xFF000000,
    0xFFADADAD,0xFF155FD9,0xFF4240FF,0xFF7527FE,0xFFA01ACC,0xFFB71E7B,0xFFB53120,0xFF994E00,
    0xFF6B6D00,0xFF388700,0xFF0C9300,0xFF008F32,0xFF007C8D,0xFF000000,0xFF000000,0xFF000000,
    0xFFFFFEFF,0xFF64B0FF,0xFF9290FF,0xFFC676FF,0xFFF36AFF,0xFFFE6ECC,0xFFFE8170,0xFFEA9E22,
    0xFFBCBE00,0xFF88D800,0xFF5CE430,0xFF45E082,0xFF48CDDE,0xFF4F4F4F,0xFF000000,0xFF000000,
    0xFFFFFEFF,0xFFC0DFFF,0xFFD3D2FF,0xFFE8C8FF,0xFFFBC2FF,0xFFFEC4EA,0xFFFECCC5,0xFFF7D8A5,
    0xFFE4E594,0xFFCFEF96,0xFFBDF4AB,0xFFB3F3CC,0xFFB5EBF2,0xFFB8B8B8,0xFF000000,0xFF000000,
};

static uint16_t mirror_nametable(Cartridge *cart, uint16_t addr) {
    addr = (addr - 0x2000) & 0x0FFF;
    switch (cart->mirror) {
    case MIRROR_HORIZONTAL:
        return (addr < 0x800) ? (addr & 0x3FF) : (0x400 + (addr & 0x3FF));
    case MIRROR_VERTICAL:   return addr & 0x7FF;
    case MIRROR_SINGLE_LO:  return addr & 0x3FF;
    case MIRROR_SINGLE_HI:  return 0x400 + (addr & 0x3FF);
    default:                return addr & 0x7FF;
    }
}

static uint8_t ppu_read(PPU *ppu, Cartridge *cart, uint16_t addr) {
    addr &= 0x3FFF;
    if (addr < 0x2000) return cartridge_ppu_read(cart, addr);
    if (addr < 0x3F00) return ppu->vram[mirror_nametable(cart, addr)];
    { uint16_t pa = addr & 0x1F; if (pa >= 16 && (pa&3)==0) pa -= 16; return ppu->palette[pa]; }
}

static void ppu_write(PPU *ppu, Cartridge *cart, uint16_t addr, uint8_t val) {
    addr &= 0x3FFF;
    if (addr < 0x2000) { cartridge_ppu_write(cart, addr, val); return; }
    if (addr < 0x3F00) { ppu->vram[mirror_nametable(cart, addr)] = val; return; }
    { uint16_t pa = addr & 0x1F; if (pa >= 16 && (pa&3)==0) pa -= 16; ppu->palette[pa] = val; }
}

static uint8_t ppu_reg_read(PPU *ppu, Cartridge *cart, uint16_t reg) {
    uint8_t result = 0;
    switch (reg & 7) {
    case 2:
        result = (ppu->status & 0xE0) | (ppu->data_buf & 0x1F);
        ppu->status &= ~PPUSTAT_VBLANK;
        ppu->nmi_occurred = 0;
        ppu->w = 0;
        break;
    case 4:
        result = ppu->oam[ppu->oam_addr];
        break;
    case 7:
        result = ppu->data_buf;
        ppu->data_buf = ppu_read(ppu, cart, ppu->v);
        if ((ppu->v & 0x3FFF) >= 0x3F00) {
            result = ppu->data_buf;
            ppu->data_buf = ppu_read(ppu, cart, ppu->v - 0x1000);
        }
        ppu->v += (ppu->ctrl & PPUCTRL_VRAM_INC) ? 32 : 1;
        break;
    }
    return result;
}

static void ppu_reg_write(PPU *ppu, Cartridge *cart, uint16_t reg, uint8_t val) {
    (void)cart;
    switch (reg & 7) {
    case 0:
        ppu->ctrl = val;
        ppu->nmi_output = (val & PPUCTRL_NMI_ENABLE) ? 1 : 0;
        ppu->t = (ppu->t & 0xF3FF) | ((uint16_t)(val & 0x03) << 10);
        break;
    case 1: ppu->mask = val; break;
    case 3: ppu->oam_addr = val; break;
    case 4: ppu->oam[ppu->oam_addr++] = val; break;
    case 5:
        if (ppu->w == 0) {
            ppu->t = (ppu->t & 0xFFE0) | ((uint16_t)val >> 3);
            ppu->fine_x = val & 0x07;
            ppu->w = 1;
        } else {
            ppu->t = (ppu->t & 0x8C1F) | ((uint16_t)(val&0x07)<<12) | ((uint16_t)(val>>3)<<5);
            ppu->w = 0;
        }
        break;
    case 6:
        if (ppu->w == 0) {
            ppu->t = (ppu->t & 0x00FF) | ((uint16_t)(val & 0x3F) << 8);
            ppu->w = 1;
        } else {
            ppu->t = (ppu->t & 0xFF00) | val;
            ppu->v = ppu->t;
            ppu->w = 0;
        }
        break;
    case 7:
        ppu_write(ppu, cart, ppu->v, val);
        ppu->v += (ppu->ctrl & PPUCTRL_VRAM_INC) ? 32 : 1;
        break;
    }
}

static void ppu_reset(PPU *ppu) {
    memset(ppu, 0, sizeof(PPU));
    ppu->scanline = -1;
}

static inline int rendering_enabled(PPU *ppu) {
    return (ppu->mask & (PPUMASK_BG_ENABLE | PPUMASK_SPR_ENABLE)) != 0;
}

static void increment_x(PPU *ppu) {
    if ((ppu->v & 0x001F) == 31) { ppu->v &= ~0x001F; ppu->v ^= 0x0400; }
    else ppu->v++;
}

static void increment_y(PPU *ppu) {
    if ((ppu->v & 0x7000) != 0x7000) { ppu->v += 0x1000; }
    else {
        ppu->v &= ~0x7000;
        int cy = (ppu->v & 0x03E0) >> 5;
        if (cy == 29)      { cy = 0; ppu->v ^= 0x0800; }
        else if (cy == 31) { cy = 0; }
        else               { cy++; }
        ppu->v = (ppu->v & ~0x03E0) | (cy << 5);
    }
}

static void copy_horizontal(PPU *p) { p->v = (p->v & ~0x041F) | (p->t & 0x041F); }
static void copy_vertical(PPU *p)   { p->v = (p->v & ~0x7BE0) | (p->t & 0x7BE0); }

static void render_bg_scanline(PPU *ppu, Cartridge *cart,
                               uint8_t *bg_px, uint8_t *bg_pal) {
    uint16_t v = ppu->v;
    uint8_t fx = ppu->fine_x;
    int show_bg   = (ppu->mask & PPUMASK_BG_ENABLE) ? 1 : 0;
    int show_left = (ppu->mask & PPUMASK_BG_LEFT)   ? 1 : 0;

    for (int x = 0; x < 256; x++) {
        uint8_t pixel = 0, palette = 0;
        if (show_bg && (x >= 8 || show_left)) {
            uint16_t nt = 0x2000 | (v & 0x0FFF);
            uint8_t tile = ppu_read(ppu, cart, nt);
            uint16_t at = 0x23C0|(v&0x0C00)|((v>>4)&0x38)|((v>>2)&0x07);
            uint8_t ab = ppu_read(ppu, cart, at);
            palette = (ab >> (((v>>4)&4)|(v&2))) & 3;
            uint16_t pb = (ppu->ctrl & PPUCTRL_BG_ADDR) ? 0x1000 : 0;
            uint16_t pa = pb + (uint16_t)tile*16 + ((v>>12)&7);
            uint8_t lo = ppu_read(ppu, cart, pa);
            uint8_t hi = ppu_read(ppu, cart, pa+8);
            uint8_t bit = 7 - fx;
            pixel = ((lo>>bit)&1) | (((hi>>bit)&1)<<1);
        }
        bg_px[x]  = pixel;
        bg_pal[x] = palette;
        if (fx == 7) { fx = 0; increment_x(ppu); v = ppu->v; } else fx++;
    }
}

static void render_sprites(PPU *ppu, Cartridge *cart, int scanline,
                           const uint8_t *bg_px, const uint8_t *bg_pal,
                           uint32_t *line) {
    int show_spr  = (ppu->mask & PPUMASK_SPR_ENABLE) ? 1 : 0;
    int show_left = (ppu->mask & PPUMASK_SPR_LEFT)   ? 1 : 0;
    int spr_h     = (ppu->ctrl & PPUCTRL_SPR_SIZE) ? 16 : 8;
    int count = 0;

    uint8_t sp_px[256], sp_pal[256], sp_pri[256], sp_z[256];
    memset(sp_px, 0, 256);
    memset(sp_z,  0, 256);

    if (!show_spr) goto compose;

    for (int i = 63; i >= 0; i--) {
        int y    = ppu->oam[i*4+0] + 1;
        int tile = ppu->oam[i*4+1];
        int attr = ppu->oam[i*4+2];
        int sx   = ppu->oam[i*4+3];
        int row  = scanline - y;
        if (row < 0 || row >= spr_h) continue;
        count++;

        int fv = (attr & 0x80) ? 1 : 0;
        int fh = (attr & 0x40) ? 1 : 0;
        uint8_t pal = (attr & 0x03) + 4;
        uint8_t pri = (attr & 0x20) ? 1 : 0;

        uint16_t pa;
        if (spr_h == 8) {
            int r = fv ? (7-row) : row;
            pa = ((ppu->ctrl & PPUCTRL_SPR_ADDR) ? 0x1000 : 0) + (uint16_t)tile*16 + r;
        } else {
            uint16_t base = (tile&1) ? 0x1000 : 0;
            int t = tile & 0xFE, r = fv ? (15-row) : row;
            if (r >= 8) { t++; r -= 8; }
            pa = base + (uint16_t)t*16 + r;
        }
        uint8_t lo = ppu_read(ppu, cart, pa);
        uint8_t hi = ppu_read(ppu, cart, pa+8);
        for (int px = 0; px < 8; px++) {
            int dx = sx + px;
            if (dx >= 256) continue;
            if (dx < 8 && !show_left) continue;
            int bit = fh ? px : (7-px);
            uint8_t p = ((lo>>bit)&1) | (((hi>>bit)&1)<<1);
            if (!p) continue;
            sp_px[dx] = p; sp_pal[dx] = pal; sp_pri[dx] = pri;
            if (i == 0) sp_z[dx] = 1;
        }
    }
    if (count > 8) ppu->status |= PPUSTAT_OVERFLOW;

compose:
    for (int x = 0; x < 256; x++) {
        uint8_t bp = bg_px[x], sp = sp_px[x], ci;
        if (sp_z[x] && bp && sp && show_spr && (ppu->mask & PPUMASK_BG_ENABLE))
            if (x >= 8 || ((ppu->mask & PPUMASK_BG_LEFT) && (ppu->mask & PPUMASK_SPR_LEFT)))
                ppu->status |= PPUSTAT_SPR0_HIT;
        if (!bp && !sp)      ci = ppu_read(ppu, cart, 0x3F00);
        else if (!bp &&  sp) ci = ppu_read(ppu, cart, 0x3F00 + sp_pal[x]*4 + sp);
        else if ( bp && !sp) ci = ppu_read(ppu, cart, 0x3F00 + bg_pal[x]*4 + bp);
        else ci = (sp_pri[x] == 0)
                ? ppu_read(ppu, cart, 0x3F00 + sp_pal[x]*4 + sp)
                : ppu_read(ppu, cart, 0x3F00 + bg_pal[x]*4 + bp);
        line[x] = nes_palette[ci & 0x3F];
    }
}

static void ppu_step(PPU *ppu, Bus *bus) {
    Cartridge *cart = bus->cart;
    int pre = (ppu->scanline == -1);
    int vis = (ppu->scanline >= 0 && ppu->scanline < 240);
    int ren = rendering_enabled(ppu);

    if (vis && ppu->cycle == 256) {
        if (ren) {
            uint8_t bp[256], bpal[256];
            copy_horizontal(ppu);
            render_bg_scanline(ppu, cart, bp, bpal);
            render_sprites(ppu, cart, ppu->scanline, bp, bpal,
                           &ppu->framebuffer[ppu->scanline * 256]);
            increment_y(ppu);
        } else {
            uint8_t bg = ppu->palette[0] & 0x3F;
            uint32_t *ln = &ppu->framebuffer[ppu->scanline * 256];
            for (int x = 0; x < 256; x++) ln[x] = nes_palette[bg];
        }
    }

    if (pre) {
        if (ppu->cycle == 1) {
            ppu->status &= ~(PPUSTAT_VBLANK | PPUSTAT_SPR0_HIT | PPUSTAT_OVERFLOW);
            ppu->nmi_occurred = 0;
        }
        if (ren && ppu->cycle >= 280 && ppu->cycle <= 304) copy_vertical(ppu);
    }

    if (ppu->scanline == 241 && ppu->cycle == 1) {
        ppu->status |= PPUSTAT_VBLANK;
        ppu->nmi_occurred = 1;
        if (ppu->nmi_output) bus->cpu.nmi_pending = 1;
        ppu->frame_ready = 1;
    }

    ppu->cycle++;
    if (ppu->cycle > 340) {
        ppu->cycle = 0;
        ppu->scanline++;
        if (ppu->scanline > 260) { ppu->scanline = -1; ppu->frame_count++; }
    }
}

/* ================================================================
 * CPU - MOS 6502
 * ================================================================ */
#define X INS_XXX
static const OpcodeEntry opcode_table[256] = {
    {INS_BRK,AM_IMP,7,0},{INS_ORA,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ORA,AM_ZPG,3,0},{INS_ASL,AM_ZPG,5,0},{X,AM_IMP,2,0},
    {INS_PHP,AM_IMP,3,0},{INS_ORA,AM_IMM,2,0},{INS_ASL,AM_ACC,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ORA,AM_ABS,4,0},{INS_ASL,AM_ABS,6,0},{X,AM_IMP,2,0},
    {INS_BPL,AM_REL,2,0},{INS_ORA,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ORA,AM_ZPX,4,0},{INS_ASL,AM_ZPX,6,0},{X,AM_IMP,2,0},
    {INS_CLC,AM_IMP,2,0},{INS_ORA,AM_ABY,4,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ORA,AM_ABX,4,1},{INS_ASL,AM_ABX,7,0},{X,AM_IMP,2,0},
    {INS_JSR,AM_ABS,6,0},{INS_AND,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_BIT,AM_ZPG,3,0},{INS_AND,AM_ZPG,3,0},{INS_ROL,AM_ZPG,5,0},{X,AM_IMP,2,0},
    {INS_PLP,AM_IMP,4,0},{INS_AND,AM_IMM,2,0},{INS_ROL,AM_ACC,2,0},{X,AM_IMP,2,0},
    {INS_BIT,AM_ABS,4,0},{INS_AND,AM_ABS,4,0},{INS_ROL,AM_ABS,6,0},{X,AM_IMP,2,0},
    {INS_BMI,AM_REL,2,0},{INS_AND,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_AND,AM_ZPX,4,0},{INS_ROL,AM_ZPX,6,0},{X,AM_IMP,2,0},
    {INS_SEC,AM_IMP,2,0},{INS_AND,AM_ABY,4,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_AND,AM_ABX,4,1},{INS_ROL,AM_ABX,7,0},{X,AM_IMP,2,0},
    {INS_RTI,AM_IMP,6,0},{INS_EOR,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_EOR,AM_ZPG,3,0},{INS_LSR,AM_ZPG,5,0},{X,AM_IMP,2,0},
    {INS_PHA,AM_IMP,3,0},{INS_EOR,AM_IMM,2,0},{INS_LSR,AM_ACC,2,0},{X,AM_IMP,2,0},
    {INS_JMP,AM_ABS,3,0},{INS_EOR,AM_ABS,4,0},{INS_LSR,AM_ABS,6,0},{X,AM_IMP,2,0},
    {INS_BVC,AM_REL,2,0},{INS_EOR,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_EOR,AM_ZPX,4,0},{INS_LSR,AM_ZPX,6,0},{X,AM_IMP,2,0},
    {INS_CLI,AM_IMP,2,0},{INS_EOR,AM_ABY,4,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_EOR,AM_ABX,4,1},{INS_LSR,AM_ABX,7,0},{X,AM_IMP,2,0},
    {INS_RTS,AM_IMP,6,0},{INS_ADC,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ADC,AM_ZPG,3,0},{INS_ROR,AM_ZPG,5,0},{X,AM_IMP,2,0},
    {INS_PLA,AM_IMP,4,0},{INS_ADC,AM_IMM,2,0},{INS_ROR,AM_ACC,2,0},{X,AM_IMP,2,0},
    {INS_JMP,AM_IND,5,0},{INS_ADC,AM_ABS,4,0},{INS_ROR,AM_ABS,6,0},{X,AM_IMP,2,0},
    {INS_BVS,AM_REL,2,0},{INS_ADC,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ADC,AM_ZPX,4,0},{INS_ROR,AM_ZPX,6,0},{X,AM_IMP,2,0},
    {INS_SEI,AM_IMP,2,0},{INS_ADC,AM_ABY,4,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_ADC,AM_ABX,4,1},{INS_ROR,AM_ABX,7,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_STA,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_STY,AM_ZPG,3,0},{INS_STA,AM_ZPG,3,0},{INS_STX,AM_ZPG,3,0},{X,AM_IMP,2,0},
    {INS_DEY,AM_IMP,2,0},{X,AM_IMP,2,0},      {INS_TXA,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_STY,AM_ABS,4,0},{INS_STA,AM_ABS,4,0},{INS_STX,AM_ABS,4,0},{X,AM_IMP,2,0},
    {INS_BCC,AM_REL,2,0},{INS_STA,AM_IZY,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_STY,AM_ZPX,4,0},{INS_STA,AM_ZPX,4,0},{INS_STX,AM_ZPY,4,0},{X,AM_IMP,2,0},
    {INS_TYA,AM_IMP,2,0},{INS_STA,AM_ABY,5,0},{INS_TXS,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_STA,AM_ABX,5,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_LDY,AM_IMM,2,0},{INS_LDA,AM_IZX,6,0},{INS_LDX,AM_IMM,2,0},{X,AM_IMP,2,0},
    {INS_LDY,AM_ZPG,3,0},{INS_LDA,AM_ZPG,3,0},{INS_LDX,AM_ZPG,3,0},{X,AM_IMP,2,0},
    {INS_TAY,AM_IMP,2,0},{INS_LDA,AM_IMM,2,0},{INS_TAX,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_LDY,AM_ABS,4,0},{INS_LDA,AM_ABS,4,0},{INS_LDX,AM_ABS,4,0},{X,AM_IMP,2,0},
    {INS_BCS,AM_REL,2,0},{INS_LDA,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_LDY,AM_ZPX,4,0},{INS_LDA,AM_ZPX,4,0},{INS_LDX,AM_ZPY,4,0},{X,AM_IMP,2,0},
    {INS_CLV,AM_IMP,2,0},{INS_LDA,AM_ABY,4,1},{INS_TSX,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_LDY,AM_ABX,4,1},{INS_LDA,AM_ABX,4,1},{INS_LDX,AM_ABY,4,1},{X,AM_IMP,2,0},
    {INS_CPY,AM_IMM,2,0},{INS_CMP,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_CPY,AM_ZPG,3,0},{INS_CMP,AM_ZPG,3,0},{INS_DEC,AM_ZPG,5,0},{X,AM_IMP,2,0},
    {INS_INY,AM_IMP,2,0},{INS_CMP,AM_IMM,2,0},{INS_DEX,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_CPY,AM_ABS,4,0},{INS_CMP,AM_ABS,4,0},{INS_DEC,AM_ABS,6,0},{X,AM_IMP,2,0},
    {INS_BNE,AM_REL,2,0},{INS_CMP,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_CMP,AM_ZPX,4,0},{INS_DEC,AM_ZPX,6,0},{X,AM_IMP,2,0},
    {INS_CLD,AM_IMP,2,0},{INS_CMP,AM_ABY,4,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_CMP,AM_ABX,4,1},{INS_DEC,AM_ABX,7,0},{X,AM_IMP,2,0},
    {INS_CPX,AM_IMM,2,0},{INS_SBC,AM_IZX,6,0},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_CPX,AM_ZPG,3,0},{INS_SBC,AM_ZPG,3,0},{INS_INC,AM_ZPG,5,0},{X,AM_IMP,2,0},
    {INS_INX,AM_IMP,2,0},{INS_SBC,AM_IMM,2,0},{INS_NOP,AM_IMP,2,0},{X,AM_IMP,2,0},
    {INS_CPX,AM_ABS,4,0},{INS_SBC,AM_ABS,4,0},{INS_INC,AM_ABS,6,0},{X,AM_IMP,2,0},
    {INS_BEQ,AM_REL,2,0},{INS_SBC,AM_IZY,5,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_SBC,AM_ZPX,4,0},{INS_INC,AM_ZPX,6,0},{X,AM_IMP,2,0},
    {INS_SED,AM_IMP,2,0},{INS_SBC,AM_ABY,4,1},{X,AM_IMP,2,0},{X,AM_IMP,2,0},
    {X,AM_IMP,2,0},      {INS_SBC,AM_ABX,4,1},{INS_INC,AM_ABX,7,0},{X,AM_IMP,2,0},
};
#undef X

static inline void set_flag(CPU *c, uint8_t f, int v) {
    if (v) c->p |= f; else c->p &= ~f;
}
static inline void update_nz(CPU *c, uint8_t v) {
    set_flag(c, FLAG_Z, v==0); set_flag(c, FLAG_N, v&0x80);
}
static inline void push8(CPU *c, Bus *b, uint8_t v) {
    bus_cpu_write(b, 0x0100+c->sp, v); c->sp--;
}
static inline void push16(CPU *c, Bus *b, uint16_t v) {
    push8(c, b, (uint8_t)(v>>8)); push8(c, b, (uint8_t)(v&0xFF));
}
static inline uint8_t pull8(CPU *c, Bus *b) {
    c->sp++; return bus_cpu_read(b, 0x0100+c->sp);
}
static inline uint16_t pull16(CPU *c, Bus *b) {
    uint16_t lo = pull8(c,b), hi = pull8(c,b); return (hi<<8)|lo;
}
static inline int pages_differ(uint16_t a, uint16_t b) {
    return (a&0xFF00)!=(b&0xFF00);
}

static uint16_t resolve_addr(CPU *cpu, Bus *bus, AddrMode mode, int *pxc) {
    uint16_t addr = 0, lo, hi;
    *pxc = 0;
    switch (mode) {
    case AM_IMP: case AM_ACC: break;
    case AM_IMM: addr = cpu->pc++; break;
    case AM_ZPG: addr = bus_cpu_read(bus, cpu->pc++) & 0xFF; break;
    case AM_ZPX: addr = (bus_cpu_read(bus, cpu->pc++) + cpu->x) & 0xFF; break;
    case AM_ZPY: addr = (bus_cpu_read(bus, cpu->pc++) + cpu->y) & 0xFF; break;
    case AM_REL: addr = cpu->pc++; break;
    case AM_ABS:
        lo = bus_cpu_read(bus, cpu->pc++); hi = bus_cpu_read(bus, cpu->pc++);
        addr = (hi<<8)|lo; break;
    case AM_ABX:
        lo = bus_cpu_read(bus, cpu->pc++); hi = bus_cpu_read(bus, cpu->pc++);
        addr = ((hi<<8)|lo)+cpu->x; *pxc = pages_differ(addr,(hi<<8)|lo); break;
    case AM_ABY:
        lo = bus_cpu_read(bus, cpu->pc++); hi = bus_cpu_read(bus, cpu->pc++);
        addr = ((hi<<8)|lo)+cpu->y; *pxc = pages_differ(addr,(hi<<8)|lo); break;
    case AM_IND:
        lo = bus_cpu_read(bus, cpu->pc++); hi = bus_cpu_read(bus, cpu->pc++);
        { uint16_t p=(hi<<8)|lo, ph=(lo==0xFF)?(p&0xFF00):(p+1);
          addr = bus_cpu_read(bus,p)|((uint16_t)bus_cpu_read(bus,ph)<<8); }
        break;
    case AM_IZX:
        { uint8_t b=bus_cpu_read(bus,cpu->pc++), z=(b+cpu->x)&0xFF;
          lo=bus_cpu_read(bus,z); hi=bus_cpu_read(bus,(z+1)&0xFF);
          addr=(hi<<8)|lo; } break;
    case AM_IZY:
        { uint8_t z=bus_cpu_read(bus,cpu->pc++);
          lo=bus_cpu_read(bus,z); hi=bus_cpu_read(bus,(z+1)&0xFF);
          addr=((hi<<8)|lo)+cpu->y; *pxc=pages_differ(addr,(hi<<8)|lo); } break;
    }
    return addr;
}

static int do_branch(CPU *cpu, Bus *bus, uint16_t addr, int cond) {
    if (!cond) return 0;
    int8_t off = (int8_t)bus_cpu_read(bus, addr);
    uint16_t np = cpu->pc + off;
    int ex = 1 + (pages_differ(cpu->pc, np) ? 1 : 0);
    cpu->pc = np;
    return ex;
}

static void cpu_nmi(CPU *cpu, Bus *bus) {
    push16(cpu, bus, cpu->pc);
    push8(cpu, bus, (cpu->p|FLAG_U)&~FLAG_B);
    cpu->p |= FLAG_I;
    cpu->pc = bus_cpu_read(bus,0xFFFA)|((uint16_t)bus_cpu_read(bus,0xFFFB)<<8);
    cpu->cycles += 7;
}

static void cpu_irq(CPU *cpu, Bus *bus) {
    if (cpu->p & FLAG_I) return;
    push16(cpu, bus, cpu->pc);
    push8(cpu, bus, (cpu->p|FLAG_U)&~FLAG_B);
    cpu->p |= FLAG_I;
    cpu->pc = bus_cpu_read(bus,0xFFFE)|((uint16_t)bus_cpu_read(bus,0xFFFF)<<8);
    cpu->cycles += 7;
}

static void cpu_reset(CPU *cpu, Bus *bus) {
    cpu->pc = bus_cpu_read(bus,0xFFFC)|((uint16_t)bus_cpu_read(bus,0xFFFD)<<8);
    cpu->sp = 0xFD; cpu->p = FLAG_U|FLAG_I;
    cpu->a = cpu->x = cpu->y = 0;
    cpu->cycles = 0; cpu->stall = 0;
    cpu->nmi_pending = cpu->irq_pending = 0;
}

static int cpu_step(CPU *cpu, Bus *bus) {
    int extra = 0;
    if (cpu->stall > 0) { cpu->stall--; return 1; }
    if (cpu->nmi_pending) { cpu_nmi(cpu,bus); cpu->nmi_pending=0; return 7; }
    if (cpu->irq_pending && !(cpu->p&FLAG_I)) { cpu_irq(cpu,bus); cpu->irq_pending=0; return 7; }

    uint8_t opcode = bus_cpu_read(bus, cpu->pc++);
    const OpcodeEntry *op = &opcode_table[opcode];
    AddrMode mode = (AddrMode)op->mode;
    int pxc = 0;
    uint16_t addr = resolve_addr(cpu, bus, mode, &pxc);
    int cycles = op->cycles + (pxc && op->page_penalty ? 1 : 0);

    switch ((InsType)op->ins) {
    case INS_ADC: { uint8_t v=bus_cpu_read(bus,addr); uint16_t s=(uint16_t)cpu->a+v+(cpu->p&FLAG_C?1:0);
        set_flag(cpu,FLAG_C,s>0xFF); set_flag(cpu,FLAG_V,(~(cpu->a^v)&(cpu->a^s))&0x80);
        cpu->a=(uint8_t)s; update_nz(cpu,cpu->a); } break;
    case INS_SBC: { uint8_t v=bus_cpu_read(bus,addr); uint16_t s=(uint16_t)cpu->a-v-(cpu->p&FLAG_C?0:1);
        set_flag(cpu,FLAG_C,s<0x100); set_flag(cpu,FLAG_V,((cpu->a^v)&(cpu->a^s))&0x80);
        cpu->a=(uint8_t)s; update_nz(cpu,cpu->a); } break;
    case INS_AND: cpu->a &= bus_cpu_read(bus,addr); update_nz(cpu,cpu->a); break;
    case INS_ORA: cpu->a |= bus_cpu_read(bus,addr); update_nz(cpu,cpu->a); break;
    case INS_EOR: cpu->a ^= bus_cpu_read(bus,addr); update_nz(cpu,cpu->a); break;
    case INS_ASL:
        if (mode==AM_ACC) { set_flag(cpu,FLAG_C,cpu->a&0x80); cpu->a<<=1; update_nz(cpu,cpu->a); }
        else { uint8_t v=bus_cpu_read(bus,addr); set_flag(cpu,FLAG_C,v&0x80); v<<=1; bus_cpu_write(bus,addr,v); update_nz(cpu,v); }
        break;
    case INS_LSR:
        if (mode==AM_ACC) { set_flag(cpu,FLAG_C,cpu->a&1); cpu->a>>=1; update_nz(cpu,cpu->a); }
        else { uint8_t v=bus_cpu_read(bus,addr); set_flag(cpu,FLAG_C,v&1); v>>=1; bus_cpu_write(bus,addr,v); update_nz(cpu,v); }
        break;
    case INS_ROL:
        if (mode==AM_ACC) { uint8_t c=(cpu->p&FLAG_C)?1:0; set_flag(cpu,FLAG_C,cpu->a&0x80); cpu->a=(cpu->a<<1)|c; update_nz(cpu,cpu->a); }
        else { uint8_t v=bus_cpu_read(bus,addr),c=(cpu->p&FLAG_C)?1:0; set_flag(cpu,FLAG_C,v&0x80); v=(v<<1)|c; bus_cpu_write(bus,addr,v); update_nz(cpu,v); }
        break;
    case INS_ROR:
        if (mode==AM_ACC) { uint8_t c=(cpu->p&FLAG_C)?0x80:0; set_flag(cpu,FLAG_C,cpu->a&1); cpu->a=(cpu->a>>1)|c; update_nz(cpu,cpu->a); }
        else { uint8_t v=bus_cpu_read(bus,addr),c=(cpu->p&FLAG_C)?0x80:0; set_flag(cpu,FLAG_C,v&1); v=(v>>1)|c; bus_cpu_write(bus,addr,v); update_nz(cpu,v); }
        break;
    case INS_CMP: { uint8_t v=bus_cpu_read(bus,addr); set_flag(cpu,FLAG_C,cpu->a>=v); update_nz(cpu,(uint8_t)(cpu->a-v)); } break;
    case INS_CPX: { uint8_t v=bus_cpu_read(bus,addr); set_flag(cpu,FLAG_C,cpu->x>=v); update_nz(cpu,(uint8_t)(cpu->x-v)); } break;
    case INS_CPY: { uint8_t v=bus_cpu_read(bus,addr); set_flag(cpu,FLAG_C,cpu->y>=v); update_nz(cpu,(uint8_t)(cpu->y-v)); } break;
    case INS_INC: { uint8_t v=bus_cpu_read(bus,addr)+1; bus_cpu_write(bus,addr,v); update_nz(cpu,v); } break;
    case INS_DEC: { uint8_t v=bus_cpu_read(bus,addr)-1; bus_cpu_write(bus,addr,v); update_nz(cpu,v); } break;
    case INS_INX: cpu->x++; update_nz(cpu,cpu->x); break;
    case INS_INY: cpu->y++; update_nz(cpu,cpu->y); break;
    case INS_DEX: cpu->x--; update_nz(cpu,cpu->x); break;
    case INS_DEY: cpu->y--; update_nz(cpu,cpu->y); break;
    case INS_LDA: cpu->a=bus_cpu_read(bus,addr); update_nz(cpu,cpu->a); break;
    case INS_LDX: cpu->x=bus_cpu_read(bus,addr); update_nz(cpu,cpu->x); break;
    case INS_LDY: cpu->y=bus_cpu_read(bus,addr); update_nz(cpu,cpu->y); break;
    case INS_STA: bus_cpu_write(bus,addr,cpu->a); break;
    case INS_STX: bus_cpu_write(bus,addr,cpu->x); break;
    case INS_STY: bus_cpu_write(bus,addr,cpu->y); break;
    case INS_TAX: cpu->x=cpu->a; update_nz(cpu,cpu->x); break;
    case INS_TAY: cpu->y=cpu->a; update_nz(cpu,cpu->y); break;
    case INS_TXA: cpu->a=cpu->x; update_nz(cpu,cpu->a); break;
    case INS_TYA: cpu->a=cpu->y; update_nz(cpu,cpu->a); break;
    case INS_TSX: cpu->x=cpu->sp; update_nz(cpu,cpu->x); break;
    case INS_TXS: cpu->sp=cpu->x; break;
    case INS_PHA: push8(cpu,bus,cpu->a); break;
    case INS_PHP: push8(cpu,bus,cpu->p|FLAG_B|FLAG_U); break;
    case INS_PLA: cpu->a=pull8(cpu,bus); update_nz(cpu,cpu->a); break;
    case INS_PLP: cpu->p=(pull8(cpu,bus)&~FLAG_B)|FLAG_U; break;
    case INS_BCC: extra=do_branch(cpu,bus,addr,!(cpu->p&FLAG_C)); break;
    case INS_BCS: extra=do_branch(cpu,bus,addr, (cpu->p&FLAG_C)); break;
    case INS_BEQ: extra=do_branch(cpu,bus,addr, (cpu->p&FLAG_Z)); break;
    case INS_BNE: extra=do_branch(cpu,bus,addr,!(cpu->p&FLAG_Z)); break;
    case INS_BMI: extra=do_branch(cpu,bus,addr, (cpu->p&FLAG_N)); break;
    case INS_BPL: extra=do_branch(cpu,bus,addr,!(cpu->p&FLAG_N)); break;
    case INS_BVS: extra=do_branch(cpu,bus,addr, (cpu->p&FLAG_V)); break;
    case INS_BVC: extra=do_branch(cpu,bus,addr,!(cpu->p&FLAG_V)); break;
    case INS_JMP: cpu->pc=addr; break;
    case INS_JSR: push16(cpu,bus,cpu->pc-1); cpu->pc=addr; break;
    case INS_RTS: cpu->pc=pull16(cpu,bus)+1; break;
    case INS_RTI: cpu->p=(pull8(cpu,bus)&~FLAG_B)|FLAG_U; cpu->pc=pull16(cpu,bus); break;
    case INS_CLC: cpu->p&=~FLAG_C; break;
    case INS_SEC: cpu->p|=FLAG_C; break;
    case INS_CLD: cpu->p&=~FLAG_D; break;
    case INS_SED: cpu->p|=FLAG_D; break;
    case INS_CLI: cpu->p&=~FLAG_I; break;
    case INS_SEI: cpu->p|=FLAG_I; break;
    case INS_CLV: cpu->p&=~FLAG_V; break;
    case INS_BIT: { uint8_t v=bus_cpu_read(bus,addr);
        set_flag(cpu,FLAG_Z,(cpu->a&v)==0); set_flag(cpu,FLAG_V,v&0x40); set_flag(cpu,FLAG_N,v&0x80); } break;
    case INS_BRK:
        cpu->pc++; push16(cpu,bus,cpu->pc); push8(cpu,bus,cpu->p|FLAG_B|FLAG_U);
        cpu->p|=FLAG_I; cpu->pc=bus_cpu_read(bus,0xFFFE)|((uint16_t)bus_cpu_read(bus,0xFFFF)<<8); break;
    case INS_NOP: break;
    case INS_XXX: break;
    }

    cycles += extra;
    cpu->cycles += cycles;
    return cycles;
}

/* ================================================================
 * Bus - Memory routing, DMA, controllers
 * ================================================================ */
static uint8_t bus_cpu_read(Bus *bus, uint16_t addr) {
    if (addr < 0x2000)       return bus->ram[addr & 0x07FF];
    if (addr < 0x4000)       return ppu_reg_read(&bus->ppu, bus->cart, addr);
    if (addr == 0x4016)    { uint8_t d=(bus->controller_latch[0]&0x80)?1:0;
                             bus->controller_latch[0]<<=1; return d|0x40; }
    if (addr == 0x4017)    { uint8_t d=(bus->controller_latch[1]&0x80)?1:0;
                             bus->controller_latch[1]<<=1; return d|0x40; }
    if (addr < 0x4020)       return 0;
    return cartridge_cpu_read(bus->cart, addr);
}

static void bus_cpu_write(Bus *bus, uint16_t addr, uint8_t val) {
    if (addr < 0x2000)     { bus->ram[addr & 0x07FF] = val; return; }
    if (addr < 0x4000)     { ppu_reg_write(&bus->ppu, bus->cart, addr, val); return; }
    if (addr == 0x4014)    { bus->dma_page=val; bus->dma_addr=0;
                             bus->dma_transfer=1; bus->dma_dummy=1; return; }
    if (addr == 0x4016)    { bus->controller_strobe=val&1;
                             if (bus->controller_strobe) {
                                 bus->controller_latch[0]=bus->controller[0];
                                 bus->controller_latch[1]=bus->controller[1]; }
                             return; }
    if (addr < 0x4020)       return;
    cartridge_cpu_write(bus->cart, addr, val);
}

static void bus_run_frame(Bus *bus) {
    bus->ppu.frame_ready = 0;
    while (!bus->ppu.frame_ready) {
        if (bus->dma_transfer) {
            /* DMA transfer */
            if (bus->dma_dummy) {
                if (bus->system_cycles & 1) bus->dma_dummy = 0;
            } else {
                if ((bus->system_cycles & 1) == 0) {
                    bus->dma_data = bus_cpu_read(bus,
                        ((uint16_t)bus->dma_page<<8)|bus->dma_addr);
                } else {
                    bus->ppu.oam[bus->ppu.oam_addr] = bus->dma_data;
                    bus->ppu.oam_addr++;
                    bus->dma_addr++;
                    if (bus->dma_addr == 0) bus->dma_transfer = 0;
                }
            }
            ppu_step(&bus->ppu, bus);
            ppu_step(&bus->ppu, bus);
            ppu_step(&bus->ppu, bus);
            bus->system_cycles++;
            continue;
        }
        int c = cpu_step(&bus->cpu, bus);
        for (int i = 0; i < c; i++) {
            ppu_step(&bus->ppu, bus);
            ppu_step(&bus->ppu, bus);
            ppu_step(&bus->ppu, bus);
            bus->system_cycles++;
        }
    }
}

/* ================================================================
 * Renderer - DirectX 12
 * ================================================================ */
static HRESULT compile_shader_from_file(LPCWSTR filename, LPCSTR entry_point,
                                        LPCSTR shader_model, ID3DBlob **blob);
static void render_wait_for_gpu(Renderer *r);
static void render_move_to_next_frame(Renderer *r);
static void render_release_target(Renderer *r);
static int render_create_target(Renderer *r, HWND hwnd);
static int render_upload_texture(Renderer *r, const uint32_t *fb);
static int render_init(Renderer *r, HWND hwnd);
static void render_destroy(Renderer *r);
static void render_resize(Renderer *r, HWND hwnd);
static void render_frame(Renderer *r, HWND hwnd, const uint32_t *fb);

static HRESULT compile_shader_from_file(LPCWSTR filename, LPCSTR entry_point,
                                        LPCSTR shader_model, ID3DBlob **blob) {
    UINT flags = D3DCOMPILE_ENABLE_STRICTNESS;
    ID3DBlob *error_blob = NULL;
    HRESULT hr = D3DCompileFromFile(filename, NULL, NULL, entry_point, shader_model,
                                    flags, 0, blob, &error_blob);
    if (error_blob) error_blob->lpVtbl->Release(error_blob);
    return hr;
}

static void render_wait_for_gpu(Renderer *r) {
    UINT i;
    if (!r->command_queue || !r->fence) return;
    for (i = 0; i < RENDER_FRAMES; i++) {
        UINT64 value = ++r->fence_value[i];
        r->command_queue->lpVtbl->Signal(r->command_queue, r->fence, value);
        if (r->fence->lpVtbl->GetCompletedValue(r->fence) < value) {
            r->fence->lpVtbl->SetEventOnCompletion(r->fence, value, r->fence_event);
            WaitForSingleObject(r->fence_event, INFINITE);
        }
    }
}

static void render_move_to_next_frame(Renderer *r) {
    UINT current = r->frame_index;
    UINT64 value = ++r->fence_value[current];
    r->command_queue->lpVtbl->Signal(r->command_queue, r->fence, value);
    r->frame_index = r->swap_chain->lpVtbl->GetCurrentBackBufferIndex(r->swap_chain);
    if (r->fence->lpVtbl->GetCompletedValue(r->fence) < r->fence_value[r->frame_index]) {
        r->fence->lpVtbl->SetEventOnCompletion(r->fence, r->fence_value[r->frame_index], r->fence_event);
        WaitForSingleObject(r->fence_event, INFINITE);
    }
}

static void render_release_target(Renderer *r) {
    UINT i;
    for (i = 0; i < RENDER_FRAMES; i++) {
        if (r->render_targets[i]) {
            r->render_targets[i]->lpVtbl->Release(r->render_targets[i]);
            r->render_targets[i] = NULL;
        }
    }
}

static int render_create_target(Renderer *r, HWND hwnd) {
    RECT rc;
    D3D12_CPU_DESCRIPTOR_HANDLE rtv_handle;
    UINT i;

    GetClientRect(hwnd, &rc);
    if (!r->swap_chain || rc.right <= rc.left || rc.bottom <= rc.top) return 0;

    render_release_target(r);
    r->rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(r->rtv_heap, &rtv_handle);
    for (i = 0; i < RENDER_FRAMES; i++) {
        if (FAILED(r->swap_chain->lpVtbl->GetBuffer(
                r->swap_chain, i, (REFIID)&IID_ID3D12Resource, (void **)&r->render_targets[i]))) {
            return 0;
        }
        r->device->lpVtbl->CreateRenderTargetView(r->device, r->render_targets[i], NULL, rtv_handle);
        rtv_handle.ptr += r->rtv_descriptor_size;
    }

    r->viewport.TopLeftX = 0.0f;
    r->viewport.TopLeftY = 0.0f;
    r->viewport.Width = (FLOAT)(rc.right - rc.left);
    r->viewport.Height = (FLOAT)(rc.bottom - rc.top);
    r->viewport.MinDepth = 0.0f;
    r->viewport.MaxDepth = 1.0f;
    r->scissor_rect.left = 0;
    r->scissor_rect.top = 0;
    r->scissor_rect.right = rc.right - rc.left;
    r->scissor_rect.bottom = rc.bottom - rc.top;
    r->frame_index = r->swap_chain->lpVtbl->GetCurrentBackBufferIndex(r->swap_chain);
    return 1;
}

static int render_upload_texture(Renderer *r, const uint32_t *fb) {
    D3D12_RANGE range = { 0, 0 };
    uint8_t *mapped = NULL;
    UINT y;

    if (!r->texture_upload) return 0;
    if (FAILED(r->texture_upload->lpVtbl->Map(r->texture_upload, 0, &range, (void **)&mapped))) return 0;
    for (y = 0; y < NES_HEIGHT; y++) {
        memcpy(mapped + (SIZE_T)r->texture_row_pitch * y,
               fb + y * NES_WIDTH,
               NES_WIDTH * sizeof(uint32_t));
    }
    r->texture_upload->lpVtbl->Unmap(r->texture_upload, 0, NULL);
    return 1;
}

static int render_init(Renderer *r, HWND hwnd) {
    static const QuadVertex vertices[] = {
        { -1.0f,  1.0f, 0.0f, 0.0f, 0.0f },
        {  1.0f,  1.0f, 0.0f, 1.0f, 0.0f },
        { -1.0f, -1.0f, 0.0f, 0.0f, 1.0f },
        {  1.0f, -1.0f, 0.0f, 1.0f, 1.0f },
    };
    static const D3D12_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT,    0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
    D3D12_COMMAND_QUEUE_DESC queue_desc;
    D3D12_DESCRIPTOR_HEAP_DESC heap_desc;
    D3D12_DESCRIPTOR_RANGE range;
    D3D12_ROOT_PARAMETER root_param;
    D3D12_STATIC_SAMPLER_DESC sampler_desc;
    D3D12_ROOT_SIGNATURE_DESC root_sig_desc;
    D3D12_GRAPHICS_PIPELINE_STATE_DESC pso_desc;
    D3D12_HEAP_PROPERTIES upload_heap;
    D3D12_HEAP_PROPERTIES default_heap;
    D3D12_RESOURCE_DESC buffer_desc;
    D3D12_RESOURCE_DESC tex_desc;
    D3D12_RESOURCE_DESC upload_desc;
    D3D12_SHADER_RESOURCE_VIEW_DESC srv_desc;
    D3D12_RESOURCE_ALLOCATION_INFO alloc_info;
    IDXGIFactory4 *factory = NULL;
    IDXGISwapChain1 *swap_chain1 = NULL;
    ID3DBlob *vs_blob = NULL;
    ID3DBlob *ps_blob = NULL;
    ID3DBlob *sig_blob = NULL;
    ID3DBlob *error_blob = NULL;
    RECT rc;
    HRESULT hr;
    UINT i;
    void *mapped = NULL;

    memset(r, 0, sizeof(Renderer));
    GetClientRect(hwnd, &rc);

    hr = CreateDXGIFactory1((REFIID)&IID_IDXGIFactory4, (void **)&factory);
    if (FAILED(hr)) return 0;
    hr = D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_11_0, (REFIID)&IID_ID3D12Device, (void **)&r->device);
    if (FAILED(hr)) { factory->lpVtbl->Release(factory); return 0; }

    memset(&queue_desc, 0, sizeof(queue_desc));
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    hr = r->device->lpVtbl->CreateCommandQueue(
        r->device, &queue_desc, (REFIID)&IID_ID3D12CommandQueue, (void **)&r->command_queue);
    if (FAILED(hr)) { factory->lpVtbl->Release(factory); return 0; }

    {
        DXGI_SWAP_CHAIN_DESC1 sd;
        memset(&sd, 0, sizeof(sd));
        sd.Width = (UINT)(rc.right - rc.left);
        sd.Height = (UINT)(rc.bottom - rc.top);
        sd.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        sd.SampleDesc.Count = 1;
        sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        sd.BufferCount = RENDER_FRAMES;
        sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        hr = factory->lpVtbl->CreateSwapChainForHwnd(
            factory, (IUnknown *)r->command_queue, hwnd, &sd, NULL, NULL, &swap_chain1);
        if (FAILED(hr)) { factory->lpVtbl->Release(factory); return 0; }
        factory->lpVtbl->MakeWindowAssociation(factory, hwnd, DXGI_MWA_NO_ALT_ENTER);
        hr = swap_chain1->lpVtbl->QueryInterface(
            swap_chain1, (REFIID)&IID_IDXGISwapChain3, (void **)&r->swap_chain);
        swap_chain1->lpVtbl->Release(swap_chain1);
        if (FAILED(hr)) { factory->lpVtbl->Release(factory); return 0; }
    }
    factory->lpVtbl->Release(factory);

    memset(&heap_desc, 0, sizeof(heap_desc));
    heap_desc.NumDescriptors = RENDER_FRAMES;
    heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    hr = r->device->lpVtbl->CreateDescriptorHeap(
        r->device, &heap_desc, (REFIID)&IID_ID3D12DescriptorHeap, (void **)&r->rtv_heap);
    if (FAILED(hr)) return 0;
    r->rtv_descriptor_size = r->device->lpVtbl->GetDescriptorHandleIncrementSize(
        r->device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    memset(&heap_desc, 0, sizeof(heap_desc));
    heap_desc.NumDescriptors = 1;
    heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    hr = r->device->lpVtbl->CreateDescriptorHeap(
        r->device, &heap_desc, (REFIID)&IID_ID3D12DescriptorHeap, (void **)&r->srv_heap);
    if (FAILED(hr)) return 0;

    memset(&range, 0, sizeof(range));
    range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
    range.NumDescriptors = 1;
    range.BaseShaderRegister = 0;
    range.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
    memset(&root_param, 0, sizeof(root_param));
    root_param.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    root_param.DescriptorTable.NumDescriptorRanges = 1;
    root_param.DescriptorTable.pDescriptorRanges = &range;
    root_param.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;

    memset(&sampler_desc, 0, sizeof(sampler_desc));
    sampler_desc.Filter = D3D12_FILTER_MIN_MAG_MIP_POINT;
    sampler_desc.AddressU = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    sampler_desc.AddressV = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    sampler_desc.AddressW = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    sampler_desc.ShaderRegister = 0;
    sampler_desc.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    sampler_desc.MaxLOD = D3D12_FLOAT32_MAX;

    memset(&root_sig_desc, 0, sizeof(root_sig_desc));
    root_sig_desc.NumParameters = 1;
    root_sig_desc.pParameters = &root_param;
    root_sig_desc.NumStaticSamplers = 1;
    root_sig_desc.pStaticSamplers = &sampler_desc;
    root_sig_desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
    hr = D3D12SerializeRootSignature(&root_sig_desc, D3D_ROOT_SIGNATURE_VERSION_1, &sig_blob, &error_blob);
    if (error_blob) error_blob->lpVtbl->Release(error_blob);
    if (FAILED(hr)) return 0;
    hr = r->device->lpVtbl->CreateRootSignature(
        r->device, 0, sig_blob->lpVtbl->GetBufferPointer(sig_blob),
        sig_blob->lpVtbl->GetBufferSize(sig_blob), (REFIID)&IID_ID3D12RootSignature,
        (void **)&r->root_signature);
    sig_blob->lpVtbl->Release(sig_blob);
    if (FAILED(hr)) return 0;

    hr = compile_shader_from_file(L"hello.hlsl", "VSMain", "vs_5_0", &vs_blob);
    if (FAILED(hr)) return 0;
    hr = compile_shader_from_file(L"hello.hlsl", "PSMain", "ps_5_0", &ps_blob);
    if (FAILED(hr)) { vs_blob->lpVtbl->Release(vs_blob); return 0; }

    memset(&pso_desc, 0, sizeof(pso_desc));
    pso_desc.pRootSignature = r->root_signature;
    pso_desc.VS.pShaderBytecode = vs_blob->lpVtbl->GetBufferPointer(vs_blob);
    pso_desc.VS.BytecodeLength = vs_blob->lpVtbl->GetBufferSize(vs_blob);
    pso_desc.PS.pShaderBytecode = ps_blob->lpVtbl->GetBufferPointer(ps_blob);
    pso_desc.PS.BytecodeLength = ps_blob->lpVtbl->GetBufferSize(ps_blob);
    for (i = 0; i < 8; i++) {
        pso_desc.BlendState.RenderTarget[i].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    }
    pso_desc.SampleMask = UINT_MAX;
    pso_desc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
    pso_desc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
    pso_desc.RasterizerState.DepthClipEnable = TRUE;
    pso_desc.DepthStencilState.DepthEnable = FALSE;
    pso_desc.DepthStencilState.StencilEnable = FALSE;
    pso_desc.InputLayout.pInputElementDescs = layout;
    pso_desc.InputLayout.NumElements = ARRAYSIZE(layout);
    pso_desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    pso_desc.NumRenderTargets = 1;
    pso_desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    pso_desc.SampleDesc.Count = 1;
    hr = r->device->lpVtbl->CreateGraphicsPipelineState(
        r->device, &pso_desc, (REFIID)&IID_ID3D12PipelineState, (void **)&r->pipeline_state);
    vs_blob->lpVtbl->Release(vs_blob);
    ps_blob->lpVtbl->Release(ps_blob);
    if (FAILED(hr)) return 0;

    for (i = 0; i < RENDER_FRAMES; i++) {
        hr = r->device->lpVtbl->CreateCommandAllocator(
            r->device, D3D12_COMMAND_LIST_TYPE_DIRECT,
            (REFIID)&IID_ID3D12CommandAllocator, (void **)&r->command_allocator[i]);
        if (FAILED(hr)) return 0;
    }
    hr = r->device->lpVtbl->CreateCommandList(
        r->device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, r->command_allocator[0],
        r->pipeline_state, (REFIID)&IID_ID3D12GraphicsCommandList, (void **)&r->command_list);
    if (FAILED(hr)) return 0;
    r->command_list->lpVtbl->Close(r->command_list);

    memset(&upload_heap, 0, sizeof(upload_heap));
    upload_heap.Type = D3D12_HEAP_TYPE_UPLOAD;
    upload_heap.CreationNodeMask = 1;
    upload_heap.VisibleNodeMask = 1;
    memset(&buffer_desc, 0, sizeof(buffer_desc));
    buffer_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    buffer_desc.Width = sizeof(vertices);
    buffer_desc.Height = 1;
    buffer_desc.DepthOrArraySize = 1;
    buffer_desc.MipLevels = 1;
    buffer_desc.SampleDesc.Count = 1;
    buffer_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    hr = r->device->lpVtbl->CreateCommittedResource(
        r->device, &upload_heap, D3D12_HEAP_FLAG_NONE, &buffer_desc,
        D3D12_RESOURCE_STATE_GENERIC_READ, NULL, (REFIID)&IID_ID3D12Resource, (void **)&r->vertex_buffer);
    if (FAILED(hr)) return 0;
    hr = r->vertex_buffer->lpVtbl->Map(r->vertex_buffer, 0, NULL, &mapped);
    if (FAILED(hr)) return 0;
    memcpy(mapped, vertices, sizeof(vertices));
    r->vertex_buffer->lpVtbl->Unmap(r->vertex_buffer, 0, NULL);
    r->vertex_buffer_view.BufferLocation = r->vertex_buffer->lpVtbl->GetGPUVirtualAddress(r->vertex_buffer);
    r->vertex_buffer_view.SizeInBytes = sizeof(vertices);
    r->vertex_buffer_view.StrideInBytes = sizeof(QuadVertex);

    memset(&default_heap, 0, sizeof(default_heap));
    default_heap.Type = D3D12_HEAP_TYPE_DEFAULT;
    default_heap.CreationNodeMask = 1;
    default_heap.VisibleNodeMask = 1;
    memset(&tex_desc, 0, sizeof(tex_desc));
    tex_desc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    tex_desc.Width = NES_WIDTH;
    tex_desc.Height = NES_HEIGHT;
    tex_desc.DepthOrArraySize = 1;
    tex_desc.MipLevels = 1;
    tex_desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN;
    hr = r->device->lpVtbl->CreateCommittedResource(
        r->device, &default_heap, D3D12_HEAP_FLAG_NONE, &tex_desc,
        D3D12_RESOURCE_STATE_COPY_DEST, NULL, (REFIID)&IID_ID3D12Resource, (void **)&r->texture);
    if (FAILED(hr)) return 0;

    memset(&srv_desc, 0, sizeof(srv_desc));
    srv_desc.Format = tex_desc.Format;
    srv_desc.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
    srv_desc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    srv_desc.Texture2D.MipLevels = 1;
    {
        D3D12_CPU_DESCRIPTOR_HANDLE srv_cpu_handle;
        r->srv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(r->srv_heap, &srv_cpu_handle);
        r->device->lpVtbl->CreateShaderResourceView(r->device, r->texture, &srv_desc, srv_cpu_handle);
    }

    r->device->lpVtbl->GetResourceAllocationInfo(r->device, &alloc_info, 0, 1, &tex_desc);
    memset(&upload_desc, 0, sizeof(upload_desc));
    upload_desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    upload_desc.Width = alloc_info.SizeInBytes;
    upload_desc.Height = 1;
    upload_desc.DepthOrArraySize = 1;
    upload_desc.MipLevels = 1;
    upload_desc.SampleDesc.Count = 1;
    upload_desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    hr = r->device->lpVtbl->CreateCommittedResource(
        r->device, &upload_heap, D3D12_HEAP_FLAG_NONE, &upload_desc,
        D3D12_RESOURCE_STATE_GENERIC_READ, NULL, (REFIID)&IID_ID3D12Resource, (void **)&r->texture_upload);
    if (FAILED(hr)) return 0;
    r->texture_row_pitch = (NES_WIDTH * sizeof(uint32_t) + D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1) &
                           ~(D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1);

    hr = r->device->lpVtbl->CreateFence(
        r->device, 0, D3D12_FENCE_FLAG_NONE, (REFIID)&IID_ID3D12Fence, (void **)&r->fence);
    if (FAILED(hr)) return 0;
    r->fence_event = CreateEventA(NULL, FALSE, FALSE, NULL);
    if (!r->fence_event) return 0;
    for (i = 0; i < RENDER_FRAMES; i++) r->fence_value[i] = 0;

    return render_create_target(r, hwnd);
}

static void render_destroy(Renderer *r) {
    UINT i;
    render_wait_for_gpu(r);
    render_release_target(r);
    if (r->fence_event) CloseHandle(r->fence_event);
    if (r->fence) r->fence->lpVtbl->Release(r->fence);
    if (r->texture_upload) r->texture_upload->lpVtbl->Release(r->texture_upload);
    if (r->texture) r->texture->lpVtbl->Release(r->texture);
    if (r->vertex_buffer) r->vertex_buffer->lpVtbl->Release(r->vertex_buffer);
    if (r->pipeline_state) r->pipeline_state->lpVtbl->Release(r->pipeline_state);
    if (r->root_signature) r->root_signature->lpVtbl->Release(r->root_signature);
    if (r->srv_heap) r->srv_heap->lpVtbl->Release(r->srv_heap);
    if (r->rtv_heap) r->rtv_heap->lpVtbl->Release(r->rtv_heap);
    if (r->command_list) r->command_list->lpVtbl->Release(r->command_list);
    for (i = 0; i < RENDER_FRAMES; i++) {
        if (r->command_allocator[i]) r->command_allocator[i]->lpVtbl->Release(r->command_allocator[i]);
    }
    if (r->command_queue) r->command_queue->lpVtbl->Release(r->command_queue);
    if (r->swap_chain) r->swap_chain->lpVtbl->Release(r->swap_chain);
    if (r->device) r->device->lpVtbl->Release(r->device);
    memset(r, 0, sizeof(Renderer));
}

static void render_resize(Renderer *r, HWND hwnd) {
    RECT rc;
    if (!r->swap_chain) return;
    GetClientRect(hwnd, &rc);
    if (rc.right <= rc.left || rc.bottom <= rc.top) return;
    render_wait_for_gpu(r);
    render_release_target(r);
    memset(r->fence_value, 0, sizeof(r->fence_value));
    r->frame_index = 0;
    r->swap_chain->lpVtbl->ResizeBuffers(
        r->swap_chain, RENDER_FRAMES, (UINT)(rc.right - rc.left), (UINT)(rc.bottom - rc.top),
        DXGI_FORMAT_R8G8B8A8_UNORM, 0);
    render_create_target(r, hwnd);
}

static void render_frame(Renderer *r, HWND hwnd, const uint32_t *fb) {
    D3D12_TEXTURE_COPY_LOCATION dst;
    D3D12_TEXTURE_COPY_LOCATION src;
    D3D12_RESOURCE_BARRIER barrier;
    D3D12_CPU_DESCRIPTOR_HANDLE rtv_handle;
    D3D12_GPU_DESCRIPTOR_HANDLE srv_handle;
    ID3D12DescriptorHeap *heaps[] = { r->srv_heap };
    ID3D12CommandList *lists[] = { (ID3D12CommandList *)r->command_list };
    float clear_color[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

    (void)hwnd;
    if (!r->command_list || !r->texture || !r->render_targets[r->frame_index]) return;
    if (!render_upload_texture(r, fb)) return;

    r->command_allocator[r->frame_index]->lpVtbl->Reset(r->command_allocator[r->frame_index]);
    r->command_list->lpVtbl->Reset(r->command_list, r->command_allocator[r->frame_index], r->pipeline_state);

    if (r->texture_initialized) {
        memset(&barrier, 0, sizeof(barrier));
        barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        barrier.Transition.pResource = r->texture;
        barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
        barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_DEST;
        r->command_list->lpVtbl->ResourceBarrier(r->command_list, 1, &barrier);
    }

    memset(&dst, 0, sizeof(dst));
    dst.pResource = r->texture;
    dst.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    dst.SubresourceIndex = 0;
    memset(&src, 0, sizeof(src));
    src.pResource = r->texture_upload;
    src.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
    src.PlacedFootprint.Footprint.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    src.PlacedFootprint.Footprint.Width = NES_WIDTH;
    src.PlacedFootprint.Footprint.Height = NES_HEIGHT;
    src.PlacedFootprint.Footprint.Depth = 1;
    src.PlacedFootprint.Footprint.RowPitch = r->texture_row_pitch;
    r->command_list->lpVtbl->CopyTextureRegion(r->command_list, &dst, 0, 0, 0, &src, NULL);

    memset(&barrier, 0, sizeof(barrier));
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = r->texture;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
    r->command_list->lpVtbl->ResourceBarrier(r->command_list, 1, &barrier);
    r->texture_initialized = 1;

    memset(&barrier, 0, sizeof(barrier));
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = r->render_targets[r->frame_index];
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
    r->command_list->lpVtbl->ResourceBarrier(r->command_list, 1, &barrier);

    r->rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(r->rtv_heap, &rtv_handle);
    rtv_handle.ptr += (SIZE_T)r->frame_index * r->rtv_descriptor_size;
    r->command_list->lpVtbl->RSSetViewports(r->command_list, 1, &r->viewport);
    r->command_list->lpVtbl->RSSetScissorRects(r->command_list, 1, &r->scissor_rect);
    r->command_list->lpVtbl->OMSetRenderTargets(r->command_list, 1, &rtv_handle, FALSE, NULL);
    r->command_list->lpVtbl->ClearRenderTargetView(r->command_list, rtv_handle, clear_color, 0, NULL);
    r->command_list->lpVtbl->SetGraphicsRootSignature(r->command_list, r->root_signature);
    r->command_list->lpVtbl->SetDescriptorHeaps(r->command_list, 1, heaps);
    r->srv_heap->lpVtbl->GetGPUDescriptorHandleForHeapStart(r->srv_heap, &srv_handle);
    r->command_list->lpVtbl->SetGraphicsRootDescriptorTable(r->command_list, 0, srv_handle);
    r->command_list->lpVtbl->IASetPrimitiveTopology(r->command_list, D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
    r->command_list->lpVtbl->IASetVertexBuffers(r->command_list, 0, 1, &r->vertex_buffer_view);
    r->command_list->lpVtbl->DrawInstanced(r->command_list, 4, 1, 0, 0);

    memset(&barrier, 0, sizeof(barrier));
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = r->render_targets[r->frame_index];
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
    r->command_list->lpVtbl->ResourceBarrier(r->command_list, 1, &barrier);

    r->command_list->lpVtbl->Close(r->command_list);
    r->command_queue->lpVtbl->ExecuteCommandLists(r->command_queue, 1, lists);
    r->swap_chain->lpVtbl->Present(r->swap_chain, 1, 0);
    render_move_to_next_frame(r);
}

/* ================================================================
 * Main - Window, input, game loop
 * ================================================================ */
#define BTN_A      0x80
#define BTN_B      0x40
#define BTN_SELECT 0x20
#define BTN_START  0x10
#define BTN_UP     0x08
#define BTN_DOWN   0x04
#define BTN_LEFT   0x02
#define BTN_RIGHT  0x01

static Bus      g_bus;
static Cartridge g_cart;
static Renderer g_renderer;
static int      g_running = 1;

static void update_input(void) {
    uint8_t s = 0;
    if (GetAsyncKeyState('Z')&0x8000)       s|=BTN_A;
    if (GetAsyncKeyState('X')&0x8000)       s|=BTN_B;
    if (GetAsyncKeyState(VK_RSHIFT)&0x8000) s|=BTN_SELECT;
    if (GetAsyncKeyState(VK_RETURN)&0x8000) s|=BTN_START;
    if (GetAsyncKeyState(VK_UP)&0x8000)     s|=BTN_UP;
    if (GetAsyncKeyState(VK_DOWN)&0x8000)   s|=BTN_DOWN;
    if (GetAsyncKeyState(VK_LEFT)&0x8000)   s|=BTN_LEFT;
    if (GetAsyncKeyState(VK_RIGHT)&0x8000)  s|=BTN_RIGHT;
    g_bus.controller[0] = s;
}

static LRESULT CALLBACK wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_DESTROY: g_running=0; PostQuitMessage(0); return 0;
    case WM_KEYDOWN: if (wp==VK_ESCAPE) { g_running=0; PostQuitMessage(0); } return 0;
    case WM_SIZE:
        if (g_renderer.swap_chain && wp != SIZE_MINIMIZED) render_resize(&g_renderer, hwnd);
        return 0;
    case WM_PAINT: {
        PAINTSTRUCT ps;
        BeginPaint(hwnd,&ps);
        EndPaint(hwnd,&ps);
        return 0; }
    default: return DefWindowProcA(hwnd,msg,wp,lp);
    }
}

int main(int argc, char *argv[]) {
    LARGE_INTEGER freq, last;
    double accum = 0.0;
    const double frame_us = 1000000.0 / 60.0988;
    MSG msg;
    WNDCLASSA wc;
    RECT rc;
    HWND hwnd;

    const char *rom_path = (argc >= 2) ? argv[1] : "triangle.nes";

    if (!cartridge_load(&g_cart, rom_path)) {
        fprintf(stderr, "Usage: %s <rom.nes>\n", argv[0]);
        return 1;
    }

    memset(&wc, 0, sizeof(wc));
    wc.lpfnWndProc  = wnd_proc;
    wc.hInstance     = GetModuleHandleA(NULL);
    wc.hCursor       = LoadCursorA(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wc.lpszClassName = "NES";
    RegisterClassA(&wc);

    rc.left=0; rc.top=0; rc.right=WINDOW_WIDTH; rc.bottom=WINDOW_HEIGHT;
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW & ~(WS_THICKFRAME|WS_MAXIMIZEBOX), FALSE);
    hwnd = CreateWindowA("NES","NES Emulator",
        WS_OVERLAPPEDWINDOW & ~(WS_THICKFRAME|WS_MAXIMIZEBOX),
        CW_USEDEFAULT,CW_USEDEFAULT, rc.right-rc.left,rc.bottom-rc.top,
        NULL,NULL,wc.hInstance,NULL);
    if (!hwnd) { cartridge_free(&g_cart); return 1; }
    if (!render_init(&g_renderer, hwnd)) { cartridge_free(&g_cart); return 1; }

    memset(&g_bus, 0, sizeof(g_bus));
    g_bus.cart = &g_cart;
    ppu_reset(&g_bus.ppu);
    cpu_reset(&g_bus.cpu, &g_bus);

    ShowWindow(hwnd, SW_SHOW);
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&last);

    while (g_running) {
        while (PeekMessageA(&msg,NULL,0,0,PM_REMOVE)) {
            if (msg.message==WM_QUIT) { g_running=0; break; }
            TranslateMessage(&msg); DispatchMessageA(&msg);
        }
        if (!g_running) break;

        LARGE_INTEGER now; QueryPerformanceCounter(&now);
        accum += (double)(now.QuadPart-last.QuadPart)*1000000.0/freq.QuadPart;
        last = now;

        if (accum >= frame_us) {
            if (accum > frame_us*3) accum = frame_us;
            accum -= frame_us;
            update_input();
            bus_run_frame(&g_bus);
            render_frame(&g_renderer, hwnd, g_bus.ppu.framebuffer);
        } else {
            Sleep(1);
        }
    }

    render_destroy(&g_renderer);
    cartridge_free(&g_cart);
    return 0;
}

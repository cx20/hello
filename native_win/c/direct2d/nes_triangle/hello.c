/*
 * hello.c - NES (Famicom) Emulator in a single C file
 *
 * Features:
 *   - MOS 6502 CPU (all official instructions)
 *   - PPU with background + sprite rendering
 *   - Mapper 0 (NROM) and Mapper 66 (GxROM)
 *   - Direct2D rendering (ID2D1Bitmap + DrawBitmap)
 *   - Player 1 keyboard input
 *
 * Build (MSVC):
 *   cl /O2 /W3 /D_CRT_SECURE_NO_WARNINGS hello.c /link user32.lib d2d1.lib
 *
 * Usage:
 *   hello.exe game.nes
 */

/* ================================================================
 * Includes
 * ================================================================ */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct D2D1_COLOR_F {
    FLOAT r, g, b, a;
} D2D1_COLOR_F;

typedef struct D2D1_RECT_F {
    FLOAT left, top, right, bottom;
} D2D1_RECT_F;

typedef struct D2D1_SIZE_U {
    UINT32 width, height;
} D2D1_SIZE_U;

typedef struct D2D1_SIZE_F {
    FLOAT width, height;
} D2D1_SIZE_F;

typedef struct D2D1_PIXEL_FORMAT {
    UINT32 format;
    UINT32 alphaMode;
} D2D1_PIXEL_FORMAT;

typedef struct D2D1_BITMAP_PROPERTIES {
    D2D1_PIXEL_FORMAT pixelFormat;
    FLOAT dpiX, dpiY;
} D2D1_BITMAP_PROPERTIES;

typedef struct D2D1_RENDER_TARGET_PROPERTIES {
    UINT32 type;
    D2D1_PIXEL_FORMAT pixelFormat;
    FLOAT dpiX, dpiY;
    UINT32 usage;
    UINT32 minLevel;
} D2D1_RENDER_TARGET_PROPERTIES;

typedef struct D2D1_HWND_RENDER_TARGET_PROPERTIES {
    HWND hwnd;
    D2D1_SIZE_U pixelSize;
    UINT32 presentOptions;
} D2D1_HWND_RENDER_TARGET_PROPERTIES;

#define DXGI_FORMAT_UNKNOWN 0
#define DXGI_FORMAT_B8G8R8A8_UNORM 87
#define D2D1_ALPHA_MODE_UNKNOWN 0
#define D2D1_ALPHA_MODE_IGNORE 3
#define D2D1_RENDER_TARGET_TYPE_DEFAULT 0
#define D2D1_RENDER_TARGET_USAGE_NONE 0
#define D2D1_FEATURE_LEVEL_DEFAULT 0
#define D2D1_PRESENT_OPTIONS_NONE 0
#define D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR 1
#define D2D1_FACTORY_TYPE_SINGLE_THREADED 0
#ifndef D2DERR_RECREATE_TARGET
#define D2DERR_RECREATE_TARGET ((HRESULT)0x8899000CL)
#endif

typedef struct ID2D1Factory ID2D1Factory;
typedef struct ID2D1HwndRenderTarget ID2D1HwndRenderTarget;
typedef struct ID2D1Bitmap ID2D1Bitmap;

typedef struct ID2D1FactoryVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ID2D1Factory*, REFIID, void**);
    ULONG (STDMETHODCALLTYPE *AddRef)(ID2D1Factory*);
    ULONG (STDMETHODCALLTYPE *Release)(ID2D1Factory*);
    HRESULT (STDMETHODCALLTYPE *ReloadSystemMetrics)(ID2D1Factory*);
    void (STDMETHODCALLTYPE *GetDesktopDpi)(ID2D1Factory*, FLOAT*, FLOAT*);
    HRESULT (STDMETHODCALLTYPE *CreateRectangleGeometry)(ID2D1Factory*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateRoundedRectangleGeometry)(ID2D1Factory*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateEllipseGeometry)(ID2D1Factory*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateGeometryGroup)(ID2D1Factory*, int, void**, UINT32, void**);
    HRESULT (STDMETHODCALLTYPE *CreateTransformedGeometry)(ID2D1Factory*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreatePathGeometry)(ID2D1Factory*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateStrokeStyle)(ID2D1Factory*, void*, void*, UINT32, void**);
    HRESULT (STDMETHODCALLTYPE *CreateDrawingStateBlock)(ID2D1Factory*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateWicBitmapRenderTarget)(ID2D1Factory*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateHwndRenderTarget)(
        ID2D1Factory*,
        const D2D1_RENDER_TARGET_PROPERTIES*,
        const D2D1_HWND_RENDER_TARGET_PROPERTIES*,
        ID2D1HwndRenderTarget**);
} ID2D1FactoryVtbl;

struct ID2D1Factory {
    const ID2D1FactoryVtbl *lpVtbl;
};

typedef struct ID2D1HwndRenderTargetVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ID2D1HwndRenderTarget*, REFIID, void**);
    ULONG (STDMETHODCALLTYPE *AddRef)(ID2D1HwndRenderTarget*);
    ULONG (STDMETHODCALLTYPE *Release)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *GetFactory)(ID2D1HwndRenderTarget*, ID2D1Factory**);
    HRESULT (STDMETHODCALLTYPE *CreateBitmap)(ID2D1HwndRenderTarget*, D2D1_SIZE_U, const void*, UINT32, const D2D1_BITMAP_PROPERTIES*, ID2D1Bitmap**);
    HRESULT (STDMETHODCALLTYPE *CreateBitmapFromWicBitmap)(ID2D1HwndRenderTarget*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateSharedBitmap)(ID2D1HwndRenderTarget*, REFIID, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateBitmapBrush)(ID2D1HwndRenderTarget*, void*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateSolidColorBrush)(ID2D1HwndRenderTarget*, const D2D1_COLOR_F*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateGradientStopCollection)(ID2D1HwndRenderTarget*, void*, UINT32, int, int, void**);
    HRESULT (STDMETHODCALLTYPE *CreateLinearGradientBrush)(ID2D1HwndRenderTarget*, void*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateRadialGradientBrush)(ID2D1HwndRenderTarget*, void*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateCompatibleRenderTarget)(ID2D1HwndRenderTarget*, void*, void*, void*, int, void**);
    HRESULT (STDMETHODCALLTYPE *CreateLayer)(ID2D1HwndRenderTarget*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateMesh)(ID2D1HwndRenderTarget*, void**);
    void (STDMETHODCALLTYPE *DrawLine)(ID2D1HwndRenderTarget*, void*, void*, void*, FLOAT, void*);
    void (STDMETHODCALLTYPE *DrawRectangle)(ID2D1HwndRenderTarget*, void*, void*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillRectangle)(ID2D1HwndRenderTarget*, void*, void*);
    void (STDMETHODCALLTYPE *DrawRoundedRectangle)(ID2D1HwndRenderTarget*, void*, void*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillRoundedRectangle)(ID2D1HwndRenderTarget*, void*, void*);
    void (STDMETHODCALLTYPE *DrawEllipse)(ID2D1HwndRenderTarget*, void*, void*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillEllipse)(ID2D1HwndRenderTarget*, void*, void*);
    void (STDMETHODCALLTYPE *DrawGeometry)(ID2D1HwndRenderTarget*, void*, void*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillGeometry)(ID2D1HwndRenderTarget*, void*, void*, void*);
    void (STDMETHODCALLTYPE *FillMesh)(ID2D1HwndRenderTarget*, void*, void*);
    void (STDMETHODCALLTYPE *FillOpacityMask)(ID2D1HwndRenderTarget*, void*, void*, int, void*, void*);
    void (STDMETHODCALLTYPE *DrawBitmap)(ID2D1HwndRenderTarget*, ID2D1Bitmap*, const D2D1_RECT_F*, FLOAT, int, const D2D1_RECT_F*);
    void (STDMETHODCALLTYPE *DrawTextW)(ID2D1HwndRenderTarget*, void*, UINT32, void*, void*, void*, int, int);
    void (STDMETHODCALLTYPE *DrawTextLayout)(ID2D1HwndRenderTarget*, void*, void*, void*, int);
    void (STDMETHODCALLTYPE *DrawGlyphRun)(ID2D1HwndRenderTarget*, void*, void*, void*, int);
    void (STDMETHODCALLTYPE *SetTransform)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *GetTransform)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *SetAntialiasMode)(ID2D1HwndRenderTarget*, int);
    int (STDMETHODCALLTYPE *GetAntialiasMode)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *SetTextAntialiasMode)(ID2D1HwndRenderTarget*, int);
    int (STDMETHODCALLTYPE *GetTextAntialiasMode)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *SetTextRenderingParams)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *GetTextRenderingParams)(ID2D1HwndRenderTarget*, void**);
    void (STDMETHODCALLTYPE *SetTags)(ID2D1HwndRenderTarget*, UINT64, UINT64);
    void (STDMETHODCALLTYPE *GetTags)(ID2D1HwndRenderTarget*, UINT64*, UINT64*);
    void (STDMETHODCALLTYPE *PushLayer)(ID2D1HwndRenderTarget*, void*, void*);
    void (STDMETHODCALLTYPE *PopLayer)(ID2D1HwndRenderTarget*);
    HRESULT (STDMETHODCALLTYPE *Flush)(ID2D1HwndRenderTarget*, UINT64*, UINT64*);
    void (STDMETHODCALLTYPE *SaveDrawingState)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *RestoreDrawingState)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *PushAxisAlignedClip)(ID2D1HwndRenderTarget*, void*, int);
    void (STDMETHODCALLTYPE *PopAxisAlignedClip)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *Clear)(ID2D1HwndRenderTarget*, const D2D1_COLOR_F*);
    void (STDMETHODCALLTYPE *BeginDraw)(ID2D1HwndRenderTarget*);
    HRESULT (STDMETHODCALLTYPE *EndDraw)(ID2D1HwndRenderTarget*, UINT64*, UINT64*);
    void (STDMETHODCALLTYPE *GetPixelFormat)(ID2D1HwndRenderTarget*, D2D1_PIXEL_FORMAT*);
    void (STDMETHODCALLTYPE *SetDpi)(ID2D1HwndRenderTarget*, FLOAT, FLOAT);
    void (STDMETHODCALLTYPE *GetDpi)(ID2D1HwndRenderTarget*, FLOAT*, FLOAT*);
    void (STDMETHODCALLTYPE *GetSize)(ID2D1HwndRenderTarget*, D2D1_SIZE_F*);
    void (STDMETHODCALLTYPE *GetPixelSize)(ID2D1HwndRenderTarget*, D2D1_SIZE_U*);
    UINT32 (STDMETHODCALLTYPE *GetMaximumBitmapSize)(ID2D1HwndRenderTarget*);
    BOOL (STDMETHODCALLTYPE *IsSupported)(ID2D1HwndRenderTarget*, void*);
    int (STDMETHODCALLTYPE *CheckWindowState)(ID2D1HwndRenderTarget*);
    HRESULT (STDMETHODCALLTYPE *Resize)(ID2D1HwndRenderTarget*, const D2D1_SIZE_U*);
    HWND (STDMETHODCALLTYPE *GetHwnd)(ID2D1HwndRenderTarget*);
} ID2D1HwndRenderTargetVtbl;

struct ID2D1HwndRenderTarget {
    const ID2D1HwndRenderTargetVtbl *lpVtbl;
};

typedef struct ID2D1BitmapVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ID2D1Bitmap*, REFIID, void**);
    ULONG (STDMETHODCALLTYPE *AddRef)(ID2D1Bitmap*);
    ULONG (STDMETHODCALLTYPE *Release)(ID2D1Bitmap*);
    void (STDMETHODCALLTYPE *GetFactory)(ID2D1Bitmap*, ID2D1Factory**);
    void (STDMETHODCALLTYPE *GetSize)(ID2D1Bitmap*, D2D1_SIZE_F*);
    void (STDMETHODCALLTYPE *GetPixelSize)(ID2D1Bitmap*, D2D1_SIZE_U*);
    void (STDMETHODCALLTYPE *GetPixelFormat)(ID2D1Bitmap*, D2D1_PIXEL_FORMAT*);
    void (STDMETHODCALLTYPE *GetDpi)(ID2D1Bitmap*, FLOAT*, FLOAT*);
    HRESULT (STDMETHODCALLTYPE *CopyFromBitmap)(ID2D1Bitmap*, const void*, ID2D1Bitmap*, const void*);
    HRESULT (STDMETHODCALLTYPE *CopyFromRenderTarget)(ID2D1Bitmap*, const void*, void*, const void*);
    HRESULT (STDMETHODCALLTYPE *CopyFromMemory)(ID2D1Bitmap*, const D2D1_RECT_F*, const void*, UINT32);
} ID2D1BitmapVtbl;

struct ID2D1Bitmap {
    const ID2D1BitmapVtbl *lpVtbl;
};

static const GUID IID_ID2D1Factory =
    { 0x06152247, 0x6f50, 0x465a, { 0x92, 0x45, 0x11, 0x8b, 0xfd, 0x3b, 0x60, 0x07 } };

HRESULT WINAPI D2D1CreateFactory(UINT factoryType, REFIID riid, const void *factoryOptions, void **factory);

/* ================================================================
 * Constants
 * ================================================================ */
#define NES_WIDTH      256
#define NES_HEIGHT     240
#define SCREEN_SCALE   2
#define WINDOW_WIDTH   (NES_WIDTH  * SCREEN_SCALE)
#define WINDOW_HEIGHT  (NES_HEIGHT * SCREEN_SCALE)

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
    ID2D1Factory          *factory;
    ID2D1HwndRenderTarget *target;
    ID2D1Bitmap           *bitmap;
    uint32_t *pixels;
} Renderer;

/* ================================================================
 * Forward declarations
 * ================================================================ */
static uint8_t bus_cpu_read(Bus *bus, uint16_t addr);
static void    bus_cpu_write(Bus *bus, uint16_t addr, uint8_t val);
static void    ppu_step(PPU *ppu, Bus *bus);

static void debug_log(const char *func, const char *fmt, ...) {
    char msg[512];
    int offset;
    va_list args;

    offset = _snprintf(msg, sizeof(msg), "[nes_direct2d] %s: ", func);
    if (offset < 0) offset = 0;
    if (offset >= (int)sizeof(msg)) offset = (int)sizeof(msg) - 1;

    va_start(args, fmt);
    _vsnprintf(msg + offset, sizeof(msg) - (size_t)offset - 3, fmt, args);
    va_end(args);

    msg[sizeof(msg) - 3] = '\0';
    strcat(msg, "\r\n");
    OutputDebugStringA(msg);
}

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
    debug_log(__func__, "start filename=%s", filename ? filename : "(null)");
    memset(cart, 0, sizeof(Cartridge));

    fp = fopen(filename, "rb");
    if (!fp) { fprintf(stderr, "Error: Cannot open '%s'\n", filename); debug_log(__func__, "failed fopen"); return 0; }
    if (fread(&hdr, sizeof(hdr), 1, fp) != 1) { fclose(fp); debug_log(__func__, "failed fread header"); return 0; }
    if (hdr.magic[0]!='N'||hdr.magic[1]!='E'||hdr.magic[2]!='S'||hdr.magic[3]!=0x1A) {
        fprintf(stderr, "Error: Invalid iNES file\n"); fclose(fp); debug_log(__func__, "invalid iNES header"); return 0;
    }

    cart->mapper = (hdr.flags7 & 0xF0) | (hdr.flags6 >> 4);
    if (cart->mapper != MAPPER_NROM && cart->mapper != MAPPER_GXROM) {
        fprintf(stderr, "Error: Only Mapper 0 and 66 supported (got %d)\n", cart->mapper);
        fclose(fp); debug_log(__func__, "unsupported mapper=%u", cart->mapper); return 0;
    }

    cart->mirror = (hdr.flags6 & 0x08) ? MIRROR_FOUR_SCREEN
                 : (hdr.flags6 & 0x01) ? MIRROR_VERTICAL : MIRROR_HORIZONTAL;
    if (hdr.flags6 & 0x04) fseek(fp, 512, SEEK_CUR); /* Skip trainer */

    cart->prg_banks = hdr.prg_count;
    cart->prg_size  = (uint32_t)hdr.prg_count * 16384;
    cart->prg_rom   = (uint8_t *)malloc(cart->prg_size);
    if (!cart->prg_rom || fread(cart->prg_rom, cart->prg_size, 1, fp) != 1) {
        fclose(fp); free(cart->prg_rom); debug_log(__func__, "failed loading PRG size=%u", cart->prg_size); return 0;
    }

    cart->chr_banks = hdr.chr_count;
    if (hdr.chr_count > 0) {
        cart->chr_size = (uint32_t)hdr.chr_count * 8192;
        cart->chr_rom  = (uint8_t *)malloc(cart->chr_size);
        if (!cart->chr_rom || fread(cart->chr_rom, cart->chr_size, 1, fp) != 1) {
            fclose(fp); free(cart->prg_rom); free(cart->chr_rom); debug_log(__func__, "failed loading CHR size=%u", cart->chr_size); return 0;
        }
    } else {
        cart->chr_rom = cart->chr_ram;
        cart->chr_size = 0x2000;
        cart->has_chr_ram = 1;
    }

    fclose(fp);
    printf("ROM: PRG=%dKB CHR=%dKB Mapper=%d Mirror=%d\n",
           cart->prg_size/1024, cart->chr_size/1024, cart->mapper, cart->mirror);
    debug_log(__func__, "ok prg=%uKB chr=%uKB mapper=%u mirror=%u",
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
    uint64_t start_cycles = bus->system_cycles;
    int start_frame = bus->ppu.frame_count;
    if (start_frame < 3) {
        debug_log(__func__, "start frame=%d", start_frame + 1);
    }
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
    if ((bus->ppu.frame_count % 60) == 0) {
        debug_log(__func__, "frame=%d cpu_cycles=%llu system_cycles=%llu scanline=%d",
                  bus->ppu.frame_count,
                  (unsigned long long)bus->cpu.cycles,
                  (unsigned long long)(bus->system_cycles - start_cycles),
                  bus->ppu.scanline);
    } else if (bus->ppu.frame_count == start_frame + 1 && start_frame < 5) {
        debug_log(__func__, "frame=%d completed", bus->ppu.frame_count);
    }
}

/* ================================================================
 * Renderer - Direct2D
 * ================================================================ */
static void render_discard_device_resources(Renderer *r) {
    debug_log(__func__, "release target=%p bitmap=%p", r->target, r->bitmap);
    if (r->bitmap) {
        r->bitmap->lpVtbl->Release(r->bitmap);
        r->bitmap = NULL;
    }
    if (r->target) {
        r->target->lpVtbl->Release(r->target);
        r->target = NULL;
    }
}

static int render_create_device_resources(Renderer *r, HWND hwnd) {
    HRESULT hr;
    RECT rc;
    D2D1_SIZE_U bitmap_size;
    D2D1_RENDER_TARGET_PROPERTIES rt_props;
    D2D1_HWND_RENDER_TARGET_PROPERTIES hwnd_props;
    D2D1_BITMAP_PROPERTIES bmp_props;

    if (r->target) return 1;
    debug_log(__func__, "create hwnd=%p", hwnd);

    GetClientRect(hwnd, &rc);
    rt_props.type = D2D1_RENDER_TARGET_TYPE_DEFAULT;
    rt_props.pixelFormat.format = DXGI_FORMAT_UNKNOWN;
    rt_props.pixelFormat.alphaMode = D2D1_ALPHA_MODE_UNKNOWN;
    rt_props.dpiX = 0.0f;
    rt_props.dpiY = 0.0f;
    rt_props.usage = D2D1_RENDER_TARGET_USAGE_NONE;
    rt_props.minLevel = D2D1_FEATURE_LEVEL_DEFAULT;

    hwnd_props.hwnd = hwnd;
    hwnd_props.pixelSize.width = (UINT32)(rc.right - rc.left);
    hwnd_props.pixelSize.height = (UINT32)(rc.bottom - rc.top);
    hwnd_props.presentOptions = D2D1_PRESENT_OPTIONS_NONE;

    hr = r->factory->lpVtbl->CreateHwndRenderTarget(r->factory, &rt_props, &hwnd_props, &r->target);
    if (FAILED(hr)) { debug_log(__func__, "CreateHwndRenderTarget failed hr=0x%08lX", (unsigned long)hr); return 0; }

    bmp_props.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bmp_props.pixelFormat.alphaMode = D2D1_ALPHA_MODE_IGNORE;
    bmp_props.dpiX = 96.0f;
    bmp_props.dpiY = 96.0f;
    bitmap_size.width = NES_WIDTH;
    bitmap_size.height = NES_HEIGHT;
    hr = r->target->lpVtbl->CreateBitmap(r->target, bitmap_size, NULL, 0, &bmp_props, &r->bitmap);
    if (FAILED(hr)) {
        debug_log(__func__, "CreateBitmap failed hr=0x%08lX", (unsigned long)hr);
        render_discard_device_resources(r);
        return 0;
    }
    debug_log(__func__, "ok size=%ux%u", bitmap_size.width, bitmap_size.height);
    return 1;
}

static int render_init(Renderer *r, HWND hwnd) {
    HRESULT hr;
    debug_log(__func__, "start hwnd=%p", hwnd);
    memset(r, 0, sizeof(Renderer));
    r->pixels = (uint32_t *)malloc(sizeof(uint32_t) * NES_WIDTH * NES_HEIGHT);
    if (!r->pixels) { debug_log(__func__, "malloc failed"); return 0; }

    hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
                           &IID_ID2D1Factory, NULL, (void **)&r->factory);
    if (FAILED(hr)) {
        free(r->pixels);
        r->pixels = NULL;
        debug_log(__func__, "D2D1CreateFactory failed hr=0x%08lX", (unsigned long)hr);
        return 0;
    }
    if (!render_create_device_resources(r, hwnd)) {
        if (r->factory) {
            r->factory->lpVtbl->Release(r->factory);
            r->factory = NULL;
        }
        free(r->pixels);
        r->pixels = NULL;
        debug_log(__func__, "device resource creation failed");
        return 0;
    }
    debug_log(__func__, "ok");
    return 1;
}

static void render_destroy(Renderer *r) {
    debug_log(__func__, "start");
    render_discard_device_resources(r);
    if (r->factory) {
        r->factory->lpVtbl->Release(r->factory);
        r->factory = NULL;
    }
    free(r->pixels);
    r->pixels = NULL;
}

static void render_resize(Renderer *r, UINT width, UINT height) {
    D2D1_SIZE_U size;
    if (!r->target) return;
    debug_log(__func__, "resize %ux%u", width, height);
    size.width = width;
    size.height = height;
    if (FAILED(r->target->lpVtbl->Resize(r->target, &size))) {
        debug_log(__func__, "Resize failed");
        render_discard_device_resources(r);
    }
}

static void render_present(Renderer *r, HWND hwnd) {
    HRESULT hr;
    D2D1_RECT_F dst;
    D2D1_SIZE_U pixel_size;
    D2D1_COLOR_F clear_color;
    static unsigned present_count = 0;

    if (present_count < 3) {
        debug_log(__func__, "start hwnd=%p target=%p bitmap=%p", hwnd, r->target, r->bitmap);
    }
    if (!render_create_device_resources(r, hwnd)) return;

    hr = r->bitmap->lpVtbl->CopyFromMemory(r->bitmap, NULL, r->pixels, NES_WIDTH * sizeof(uint32_t));
    if (FAILED(hr)) { debug_log(__func__, "CopyFromMemory failed hr=0x%08lX", (unsigned long)hr); return; }

    r->target->lpVtbl->GetPixelSize(r->target, &pixel_size);
    dst.left = 0.0f;
    dst.top = 0.0f;
    dst.right = (FLOAT)pixel_size.width;
    dst.bottom = (FLOAT)pixel_size.height;
    clear_color.r = 0.0f;
    clear_color.g = 0.0f;
    clear_color.b = 0.0f;
    clear_color.a = 1.0f;

    if (present_count < 3) {
        debug_log(__func__, "before BeginDraw size=%ux%u", pixel_size.width, pixel_size.height);
    }
    r->target->lpVtbl->BeginDraw(r->target);
    r->target->lpVtbl->Clear(r->target, &clear_color);
    r->target->lpVtbl->DrawBitmap(
        r->target,
        r->bitmap,
        &dst,
        1.0f,
        D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR,
        NULL);
    hr = r->target->lpVtbl->EndDraw(r->target, NULL, NULL);
    if (present_count < 3) {
        debug_log(__func__, "after EndDraw hr=0x%08lX", (unsigned long)hr);
    }
    if (hr == D2DERR_RECREATE_TARGET) {
        debug_log(__func__, "EndDraw recreate target");
        render_discard_device_resources(r);
    } else if (FAILED(hr)) {
        debug_log(__func__, "EndDraw failed hr=0x%08lX", (unsigned long)hr);
    } else if ((present_count++ % 60) == 0) {
        debug_log(__func__, "present ok size=%ux%u", pixel_size.width, pixel_size.height);
    }
}

static void render_frame(Renderer *r, HWND hwnd, const uint32_t *fb) {
    for (int i = 0; i < NES_WIDTH*NES_HEIGHT; i++) {
        r->pixels[i] = fb[i];
    }
    render_present(r, hwnd);
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
    case WM_DESTROY: debug_log(__func__, "WM_DESTROY"); g_running=0; PostQuitMessage(0); return 0;
    case WM_KEYDOWN: debug_log(__func__, "WM_KEYDOWN wp=0x%Ix", (size_t)wp); if (wp==VK_ESCAPE) { g_running=0; PostQuitMessage(0); } return 0;
    case WM_PAINT: {
        PAINTSTRUCT ps;
        debug_log(__func__, "WM_PAINT begin");
        debug_log(__func__, "before BeginPaint");
        BeginPaint(hwnd,&ps);
        debug_log(__func__, "after BeginPaint");
        debug_log(__func__, "before render_present");
        render_present(&g_renderer, hwnd);
        debug_log(__func__, "after render_present");
        EndPaint(hwnd,&ps);
        debug_log(__func__, "after EndPaint");
        return 0; }
    case WM_SIZE:
        debug_log(__func__, "WM_SIZE width=%u height=%u", LOWORD(lp), HIWORD(lp));
        render_resize(&g_renderer, LOWORD(lp), HIWORD(lp));
        return 0;
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
    debug_log(__func__, "start argc=%d rom=%s", argc, rom_path);

    if (!cartridge_load(&g_cart, rom_path)) {
        fprintf(stderr, "Usage: %s <rom.nes>\n", argv[0]);
        debug_log(__func__, "cartridge_load failed");
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
    if (!hwnd) { debug_log(__func__, "CreateWindowA failed"); cartridge_free(&g_cart); return 1; }
    debug_log(__func__, "window created hwnd=%p", hwnd);
    if (!render_init(&g_renderer, hwnd)) { debug_log(__func__, "render_init failed"); cartridge_free(&g_cart); return 1; }

    memset(&g_bus, 0, sizeof(g_bus));
    g_bus.cart = &g_cart;
    ppu_reset(&g_bus.ppu);
    cpu_reset(&g_bus.cpu, &g_bus);
    debug_log(__func__, "emulator reset pc=0x%04X", g_bus.cpu.pc);

    ShowWindow(hwnd, SW_SHOW);
    debug_log(__func__, "ShowWindow done");
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
            if (g_bus.ppu.frame_count < 3) {
                debug_log(__func__, "tick accum=%.2f frame=%d", accum, g_bus.ppu.frame_count + 1);
            }
            if (accum > frame_us*3) accum = frame_us;
            accum -= frame_us;
            update_input();
            bus_run_frame(&g_bus);
            render_frame(&g_renderer, hwnd, g_bus.ppu.framebuffer);
        } else {
            Sleep(1);
        }
    }

    debug_log(__func__, "shutdown");
    render_destroy(&g_renderer);
    cartridge_free(&g_cart);
    return 0;
}

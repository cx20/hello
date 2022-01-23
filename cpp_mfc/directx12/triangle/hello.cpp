#include <afxwin.h>
#include <tchar.h>
#include <wrl.h>
#include <comdef.h>

#include <d3d12.h>
#include <dxgi1_4.h>
#include <d3dcompiler.h>
#include <directxmath.h>
#include "d3dx12.h"

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480

using namespace DirectX;
using Microsoft::WRL::ComPtr;

struct VERTEX
{
    XMFLOAT3 position;
    XMFLOAT4 color;
};

class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    ~CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);

	HRESULT OnInit();
	HRESULT InitDevice();
	HRESULT InitView();
	HRESULT InitTraffic();
	HRESULT InitShader();
	HRESULT InitBuffer();
	HRESULT InitFence();
	void Render();
	void WaitForPreviousFrame();
protected:
	afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnPaint();
	afx_msg void OnDestroy();
    DECLARE_MESSAGE_MAP()

private:
	static const UINT                   m_frameCount = 2;

	ComPtr<ID3D12Device>                m_device;
	ComPtr<IDXGISwapChain3>             m_swapChain;
	ComPtr<ID3D12Resource>              m_renderTargets[m_frameCount];
	ComPtr<ID3D12CommandAllocator>      m_commandAllocator;
	ComPtr<ID3D12CommandQueue>          m_commandQueue;
	ComPtr<ID3D12RootSignature>         m_rootSignature;
	ComPtr<ID3D12DescriptorHeap>        m_rtvHeap;
	ComPtr<ID3D12PipelineState>         m_pipelineState;
	ComPtr<ID3D12GraphicsCommandList>   m_commandList;
	UINT                                m_rtvDescriptorSize;

    CD3DX12_VIEWPORT                    m_viewport;
    CD3DX12_RECT                        m_scissorRect;
    
	UINT                                m_frameIndex;
	HANDLE                              m_fenceEvent;
	ComPtr<ID3D12Fence>                 m_fence;
	UINT64                              m_fenceValue;

	ComPtr<ID3D12Resource>              m_vertexBuffer;
	D3D12_VERTEX_BUFFER_VIEW            m_vertexBufferView;
};

class CHelloApp : public CWinApp
{
public:
    BOOL InitInstance();
};

BOOL CHelloApp::InitInstance()
{
    m_pMainWnd = new CMainFrame;

    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}

CHelloApp App;

BEGIN_MESSAGE_MAP( CMainFrame, CFrameWnd )
    ON_WM_CREATE()
    ON_WM_PAINT()
    ON_WM_DESTROY()
END_MESSAGE_MAP()

CMainFrame::CMainFrame()
{
    m_rtvDescriptorSize = 0;
    m_frameIndex = 0;
    m_fenceEvent = NULL;
    m_fenceValue = 0;
    m_vertexBufferView = { 0 };
    m_viewport    = CD3DX12_VIEWPORT(0.0f, 0.0f, static_cast<FLOAT>(WINDOW_WIDTH), static_cast<FLOAT>(WINDOW_HEIGHT));
    m_scissorRect = CD3DX12_RECT(0, 0, static_cast<LONG>(WINDOW_WIDTH), static_cast<LONG>(WINDOW_HEIGHT));

    Create( NULL, _T("Hello, World!") );
}

CMainFrame::~CMainFrame()
{
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = 640;
    cs.cy = 480;

    return TRUE;
}

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    CFrameWnd::OnCreate(lpCreateStruct);

    OnInit();
    
    return 0;
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);

    Render();
}

HRESULT CMainFrame::OnInit()
{
    if (FAILED(InitDevice()))  return E_FAIL;
    if (FAILED(InitView()))    return E_FAIL;
    if (FAILED(InitTraffic())) return E_FAIL;
    if (FAILED(InitShader()))  return E_FAIL;
    if (FAILED(InitBuffer()))  return E_FAIL;
    if (FAILED(InitFence()))   return E_FAIL;

    return S_OK;
}

HRESULT CMainFrame::InitDevice()
{
    UINT dxgiFactoryFlags = 0;

    ComPtr<IDXGIFactory4> factory;
    if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_PPV_ARGS(factory.GetAddressOf()))))
    {
        return E_FAIL;
    }

    HRESULT hr;
    ComPtr<IDXGIAdapter1> hardwareAdapter = nullptr;
    ComPtr<IDXGIAdapter1> adapter;
    for (UINT adapterIndex = 0; DXGI_ERROR_NOT_FOUND != factory->EnumAdapters1(adapterIndex, adapter.GetAddressOf()); ++adapterIndex)
    {
        DXGI_ADAPTER_DESC1 adapterDesc;
        adapter->GetDesc1(&adapterDesc);

        if (adapterDesc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) continue;

        hr = D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0, _uuidof(ID3D12Device), nullptr);
        if (SUCCEEDED(hr))
        {
            if (FAILED(D3D12CreateDevice(hardwareAdapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(m_device.GetAddressOf()))))
            {
                return E_FAIL;
            }
            break;
        }
    }

    hardwareAdapter = adapter.Detach();

    if (FAILED(hr))
    {
        ComPtr<IDXGIAdapter> warpAdapter;
        factory->EnumWarpAdapter(IID_PPV_ARGS(warpAdapter.GetAddressOf()));
        if (FAILED(D3D12CreateDevice(warpAdapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(m_device.GetAddressOf()))))
        {
            return E_FAIL;
        }
    }

    D3D12_COMMAND_QUEUE_DESC queueDesc = {};
    queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
    queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;

    if (FAILED(m_device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(m_commandQueue.GetAddressOf()))))
    {
        return E_FAIL;
    }

    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.BufferCount      = m_frameCount;
    swapChainDesc.Width            = WINDOW_WIDTH;
    swapChainDesc.Height           = WINDOW_HEIGHT;
    swapChainDesc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.BufferUsage      = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.SwapEffect       = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.SampleDesc.Count = 1;

    ComPtr<IDXGISwapChain1> swapChain;
    if (FAILED(factory->CreateSwapChainForHwnd(m_commandQueue.Get(), m_hWnd, &swapChainDesc, nullptr, nullptr, swapChain.GetAddressOf())))
    {
        return E_FAIL;
    }

    if (FAILED(factory->MakeWindowAssociation(m_hWnd, DXGI_MWA_NO_ALT_ENTER)))
    {
        return E_FAIL;
    }

    swapChain.As(&m_swapChain);

    m_frameIndex = m_swapChain->GetCurrentBackBufferIndex();

    return S_OK;
}

HRESULT CMainFrame::InitView()
{
    {
        D3D12_DESCRIPTOR_HEAP_DESC rtvHeapDesc = {};
        rtvHeapDesc.NumDescriptors = m_frameCount;
        rtvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        rtvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

        if (FAILED(m_device->CreateDescriptorHeap(&rtvHeapDesc, IID_PPV_ARGS(m_rtvHeap.GetAddressOf()))))
        {
            return E_FAIL;
        }

        m_rtvDescriptorSize = m_device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    }

    {
        CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(m_rtvHeap->GetCPUDescriptorHandleForHeapStart());

        for (UINT i = 0; i < m_frameCount; i++)
        {
            if (FAILED(m_swapChain->GetBuffer(i, IID_PPV_ARGS(m_renderTargets[i].GetAddressOf()))))
            {
                return E_FAIL;
            }

            m_device->CreateRenderTargetView(m_renderTargets[i].Get(), nullptr, rtvHandle);

            rtvHandle.Offset(1, m_rtvDescriptorSize);
        }
    }

    return S_OK;
}

HRESULT CMainFrame::InitTraffic()
{
    if (FAILED(m_device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(m_commandAllocator.GetAddressOf()))))
    {
        return E_FAIL;
    }

    {
        CD3DX12_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Init(0, nullptr, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

        ComPtr<ID3DBlob> signature;
        ComPtr<ID3DBlob> error;
        D3D12SerializeRootSignature(&rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, signature.GetAddressOf(), error.GetAddressOf());
        if (FAILED(m_device->CreateRootSignature(0, signature->GetBufferPointer(), signature->GetBufferSize(), IID_PPV_ARGS(&m_rootSignature))))
        {
            return E_FAIL;
        }
    }

    return S_OK;
}

HRESULT CMainFrame::InitShader()
{
    {
        ComPtr<ID3DBlob> vertexShader, pixelShader;

        UINT compileFlags = 0;

        if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr, "VSMain", "vs_5_0", compileFlags, 0, vertexShader.GetAddressOf(), nullptr)))
        {
            return E_FAIL;
        }
        
        if (FAILED(D3DCompileFromFile(L"hello.hlsl", nullptr, nullptr, "PSMain", "ps_5_0", compileFlags, 0, pixelShader.GetAddressOf(), nullptr)))
        {
            return E_FAIL;
        }

        D3D12_INPUT_ELEMENT_DESC inputElementDescs[] =
        {
            {"POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
            {"COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
        };

        D3D12_GRAPHICS_PIPELINE_STATE_DESC gpsDesc = {};
        gpsDesc.InputLayout = { inputElementDescs, _countof(inputElementDescs) };
        gpsDesc.pRootSignature = m_rootSignature.Get();
        gpsDesc.VS = CD3DX12_SHADER_BYTECODE(vertexShader.Get());
        gpsDesc.PS = CD3DX12_SHADER_BYTECODE(pixelShader.Get());
        gpsDesc.RasterizerState = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
        gpsDesc.BlendState = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
        gpsDesc.DepthStencilState.DepthEnable = FALSE;
        gpsDesc.DepthStencilState.StencilEnable = FALSE;
        gpsDesc.SampleMask = UINT_MAX;
        gpsDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
        gpsDesc.NumRenderTargets = 1;
        gpsDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        gpsDesc.SampleDesc.Count = 1;

        if (FAILED(m_device->CreateGraphicsPipelineState(&gpsDesc, IID_PPV_ARGS(m_pipelineState.GetAddressOf()))))
        {
            return E_FAIL;
        }
    }

    return S_OK;
}

HRESULT CMainFrame::InitBuffer()
{
    if (FAILED(m_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, m_commandAllocator.Get(), nullptr, IID_PPV_ARGS(m_commandList.GetAddressOf()))))
    {
        return E_FAIL;
    }

    m_commandList->Close();

    {
        VERTEX vertices[] =
        {
            { XMFLOAT3(  0.0f,  0.5f, 0.0f), XMFLOAT4(1.0f, 0.0f, 0.0f, 1.0f) },
            { XMFLOAT3(  0.5f, -0.5f, 0.0f), XMFLOAT4(0.0f, 1.0f, 0.0f, 1.0f) },
            { XMFLOAT3( -0.5f, -0.5f, 0.0f), XMFLOAT4(0.0f, 0.0f, 1.0f, 1.0f) },
        };

        const UINT vertexBufferSize = sizeof(vertices);

        if (FAILED(m_device->CreateCommittedResource(&CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD), D3D12_HEAP_FLAG_NONE, &CD3DX12_RESOURCE_DESC::Buffer(vertexBufferSize), D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(m_vertexBuffer.GetAddressOf()))))
        {
            return E_FAIL;
        }

        UINT8* pVertexDataBegin;
        CD3DX12_RANGE readRange(0, 0);
        m_vertexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pVertexDataBegin));
        memcpy(pVertexDataBegin, vertices, sizeof(vertices));
        m_vertexBuffer->Unmap(0, nullptr);

        m_vertexBufferView.BufferLocation = m_vertexBuffer->GetGPUVirtualAddress();
        m_vertexBufferView.StrideInBytes  = sizeof(VERTEX);
        m_vertexBufferView.SizeInBytes    = vertexBufferSize;
    }

    return S_OK;
}

HRESULT CMainFrame::InitFence()
{
    {
        if (FAILED(m_device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(m_fence.GetAddressOf()))))
        {
            return E_FAIL;
        }

        m_fenceValue = 1;

        m_fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);
        if (m_fenceEvent == nullptr)
        {
            return E_FAIL;
        }

        WaitForPreviousFrame();
    }

    return S_OK;
}

void CMainFrame::Render()
{
    m_commandAllocator->Reset();

    m_commandList->Reset(m_commandAllocator.Get(), m_pipelineState.Get());

    m_commandList->SetGraphicsRootSignature(m_rootSignature.Get());
    m_commandList->RSSetViewports(1, &m_viewport);
    m_commandList->RSSetScissorRects(1, &m_scissorRect);

    m_commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(m_renderTargets[m_frameIndex].Get(), D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET));

    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(m_rtvHeap->GetCPUDescriptorHandleForHeapStart(), m_frameIndex, m_rtvDescriptorSize);

    m_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, nullptr);

    const FLOAT clearColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
    m_commandList->ClearRenderTargetView(rtvHandle, clearColor, 0, nullptr);
    m_commandList->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    m_commandList->IASetVertexBuffers(0, 1, &m_vertexBufferView);
    m_commandList->DrawInstanced(3, 1, 0, 0);

    m_commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(m_renderTargets[m_frameIndex].Get(), D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT));

    m_commandList->Close();

    ID3D12CommandList* ppCommandLists[] = { m_commandList.Get() };
    m_commandQueue->ExecuteCommandLists(_countof(ppCommandLists), ppCommandLists);

    m_swapChain->Present(1, 0);

    WaitForPreviousFrame();
}

void CMainFrame::WaitForPreviousFrame()
{
    const UINT64 fence = m_fenceValue;
    m_commandQueue->Signal(m_fence.Get(), fence);
    m_fenceValue++;

    if (m_fence->GetCompletedValue() < fence)
    {
        m_fence->SetEventOnCompletion(fence, m_fenceEvent);
        WaitForSingleObject(m_fenceEvent, INFINITE);
    }

    m_frameIndex = m_swapChain->GetCurrentBackBufferIndex();
}

void CMainFrame::OnDestroy()
{
	CFrameWnd::OnDestroy();

    WaitForPreviousFrame();
    CloseHandle(m_fenceEvent);
}

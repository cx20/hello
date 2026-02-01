import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.internal.win32.OS;

import com.sun.jna.*;
import com.sun.jna.ptr.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;

public class Hello {

    // ------------------------------------------------------------
    // Vulkan constants (minimal)
    // ------------------------------------------------------------
    static final int VK_SUCCESS = 0;
    static final int VK_SUBOPTIMAL_KHR = 1000001003;
    static final int VK_ERROR_OUT_OF_DATE_KHR = -1000001004;

    static final int VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
    static final int VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;
    static final int VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2;
    static final int VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3;
    static final int VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000;
    static final int VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000;
    static final int VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15;
    static final int VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16;
    static final int VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38;
    static final int VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30;
    static final int VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28;
    static final int VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
    static final int VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19;
    static final int VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
    static final int VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22;
    static final int VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
    static final int VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24;
    static final int VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26;
    static final int VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27;
    static final int VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37;
    static final int VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39;
    static final int VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40;
    static final int VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42;
    static final int VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43;
    static final int VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9;
    static final int VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8;
    static final int VK_STRUCTURE_TYPE_SUBMIT_INFO = 4;
    static final int VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001002;

    static final int VK_QUEUE_GRAPHICS_BIT = 0x00000001;

    static final int VK_KHR_SURFACE = 1;
    static final int VK_KHR_WIN32_SURFACE = 2;

    static final String VK_KHR_SURFACE_EXTENSION_NAME = "VK_KHR_surface";
    static final String VK_KHR_WIN32_SURFACE_EXTENSION_NAME = "VK_KHR_win32_surface";
    static final String VK_KHR_SWAPCHAIN_EXTENSION_NAME = "VK_KHR_swapchain";

    static final int VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010;
    static final int VK_SHARING_MODE_EXCLUSIVE = 0;
    static final int VK_SHARING_MODE_CONCURRENT = 1;

    static final int VK_PRESENT_MODE_FIFO_KHR = 2;
    static final int VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001;
    static final int VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001;

    static final int VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001;
    static final int VK_IMAGE_VIEW_TYPE_2D = 1;

    static final int VK_IMAGE_LAYOUT_UNDEFINED = 0;
    static final int VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
    static final int VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002;

    static final int VK_ATTACHMENT_LOAD_OP_CLEAR = 1;
    static final int VK_ATTACHMENT_STORE_OP_STORE = 0;

    static final int VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
    static final int VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;

    static final int VK_POLYGON_MODE_FILL = 0;
    static final int VK_CULL_MODE_NONE = 0;
    static final int VK_FRONT_FACE_COUNTER_CLOCKWISE = 1;

    static final int VK_SAMPLE_COUNT_1_BIT = 1;

    static final int VK_COLOR_COMPONENT_R_BIT = 0x1;
    static final int VK_COLOR_COMPONENT_G_BIT = 0x2;
    static final int VK_COLOR_COMPONENT_B_BIT = 0x4;
    static final int VK_COLOR_COMPONENT_A_BIT = 0x8;

    static final int VK_DYNAMIC_STATE_VIEWPORT = 0;
    static final int VK_DYNAMIC_STATE_SCISSOR  = 1;

    static final int VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400;

    static final int VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001;

    static final int VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002;
    static final int VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;

    static final int VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001;
    static final int VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010;

    // VK_MAKE_API_VERSION(0,1,4,0)
    static final int VK_API_VERSION_1_4 = (1 << 22) | (4 << 12);

    // ------------------------------------------------------------
    // JNA Vulkan loader
    // ------------------------------------------------------------
    static final NativeLibrary VK = NativeLibrary.getInstance("vulkan-1");
    static final Function vkGetInstanceProcAddr = VK.getFunction("vkGetInstanceProcAddr", Function.ALT_CONVENTION);
    static final Function vkGetDeviceProcAddr   = VK.getFunction("vkGetDeviceProcAddr",   Function.ALT_CONVENTION);

    static Function vkGlobal(String name) {
        return VK.getFunction(name, Function.ALT_CONVENTION);
    }

    static Function vkInst(Pointer instance, String name) {
        Pointer pfn = (Pointer) vkGetInstanceProcAddr.invoke(Pointer.class, new Object[]{ instance, name });
        if (pfn == null || Pointer.nativeValue(pfn) == 0) throw new RuntimeException("vkGetInstanceProcAddr failed: " + name);
        return Function.getFunction(pfn, Function.ALT_CONVENTION);
    }

    static Function vkDev(Pointer device, String name) {
        Pointer pfn = (Pointer) vkGetDeviceProcAddr.invoke(Pointer.class, new Object[]{ device, name });
        if (pfn == null || Pointer.nativeValue(pfn) == 0) throw new RuntimeException("vkGetDeviceProcAddr failed: " + name);
        return Function.getFunction(pfn, Function.ALT_CONVENTION);
    }

    static void vkCheck(int res, String what) {
        if (res != VK_SUCCESS) throw new RuntimeException(what + " failed: VkResult=" + res);
    }

    static Memory utf8z(String s) {
        byte[] b = (s + "\0").getBytes(java.nio.charset.StandardCharsets.UTF_8);
        Memory m = new Memory(b.length);
        m.write(0, b, 0, b.length);
        return m;
    }

    static byte[] readAllBytes(Path p) throws IOException {
        return Files.readAllBytes(p);
    }

    // ------------------------------------------------------------
    // Minimal Vulkan structs (JNA Structure)
    // ------------------------------------------------------------
    public static class VkApplicationInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public Pointer pApplicationName;
        public int applicationVersion;
        public Pointer pEngineName;
        public int engineVersion;
        public int apiVersion;

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("sType","pNext","pApplicationName","applicationVersion","pEngineName","engineVersion","apiVersion");
        }
    }

    public static class VkInstanceCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public Pointer pApplicationInfo; // VkApplicationInfo*
        public int enabledLayerCount;
        public Pointer ppEnabledLayerNames; // char* const*
        public int enabledExtensionCount;
        public Pointer ppEnabledExtensionNames; // char* const*

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("sType","pNext","flags","pApplicationInfo","enabledLayerCount","ppEnabledLayerNames","enabledExtensionCount","ppEnabledExtensionNames");
        }
    }

    public static class VkWin32SurfaceCreateInfoKHR extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public Pointer hinstance; // HINSTANCE
        public Pointer hwnd;      // HWND

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("sType","pNext","flags","hinstance","hwnd");
        }
    }

    public static class VkExtent2D extends Structure {
        public int width;
        public int height;
        public VkExtent2D() {}
        public VkExtent2D(int w,int h){width=w;height=h;}
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("width","height"); }
    }

    public static class VkSurfaceCapabilitiesKHR extends Structure {
        public int minImageCount;
        public int maxImageCount;
        public VkExtent2D currentExtent;
        public VkExtent2D minImageExtent;
        public VkExtent2D maxImageExtent;
        public int maxImageArrayLayers;
        public int supportedTransforms;
        public int currentTransform;
        public int supportedCompositeAlpha;
        public int supportedUsageFlags;

        public VkSurfaceCapabilitiesKHR() {
            currentExtent = new VkExtent2D();
            minImageExtent = new VkExtent2D();
            maxImageExtent = new VkExtent2D();
        }

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("minImageCount","maxImageCount","currentExtent","minImageExtent","maxImageExtent",
                    "maxImageArrayLayers","supportedTransforms","currentTransform","supportedCompositeAlpha","supportedUsageFlags");
        }
    }

    public static class VkSurfaceFormatKHR extends Structure {
        public int format;
        public int colorSpace;

        public VkSurfaceFormatKHR() {}
        public VkSurfaceFormatKHR(Pointer p) { super(p); }

        @Override protected List<String> getFieldOrder(){ return Arrays.asList("format","colorSpace"); }
    }

    public static class VkQueueFamilyProperties extends Structure {
        public int queueFlags;
        public int queueCount;
        public int timestampValidBits;
        public VkExtent3D minImageTransferGranularity = new VkExtent3D();

        public VkQueueFamilyProperties() {}
        public VkQueueFamilyProperties(Pointer p) { super(p); }

        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("queueFlags","queueCount","timestampValidBits","minImageTransferGranularity");
        }
    }

    public static class VkExtent3D extends Structure {
        public int width,height,depth;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("width","height","depth"); }
    }

    public static class VkDeviceQueueCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public int queueFamilyIndex;
        public int queueCount;
        public Pointer pQueuePriorities; // float*

        public VkDeviceQueueCreateInfo() {}
        public VkDeviceQueueCreateInfo(Pointer p) { super(p); }

        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","queueFamilyIndex","queueCount","pQueuePriorities");
        }
    }

    public static class VkDeviceCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public int queueCreateInfoCount;
        public Pointer pQueueCreateInfos; // VkDeviceQueueCreateInfo*
        public int enabledLayerCount;
        public Pointer ppEnabledLayerNames;
        public int enabledExtensionCount;
        public Pointer ppEnabledExtensionNames;
        public Pointer pEnabledFeatures;

        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","queueCreateInfoCount","pQueueCreateInfos",
                    "enabledLayerCount","ppEnabledLayerNames","enabledExtensionCount","ppEnabledExtensionNames","pEnabledFeatures");
        }
    }

    public static class VkSwapchainCreateInfoKHR extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public long surface; // VkSurfaceKHR
        public int minImageCount;
        public int imageFormat;
        public int imageColorSpace;
        public VkExtent2D imageExtent = new VkExtent2D();
        public int imageArrayLayers;
        public int imageUsage;
        public int imageSharingMode;
        public int queueFamilyIndexCount;
        public Pointer pQueueFamilyIndices; // uint32*
        public int preTransform;
        public int compositeAlpha;
        public int presentMode;
        public int clipped; // VkBool32
        public long oldSwapchain; // VkSwapchainKHR

        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","surface","minImageCount","imageFormat","imageColorSpace","imageExtent",
                    "imageArrayLayers","imageUsage","imageSharingMode","queueFamilyIndexCount","pQueueFamilyIndices",
                    "preTransform","compositeAlpha","presentMode","clipped","oldSwapchain");
        }
    }

    public static class VkComponentMapping extends Structure {
        public int r,g,b,a;
        public VkComponentMapping(){}
        public VkComponentMapping(int r,int g,int b,int a){this.r=r;this.g=g;this.b=b;this.a=a;}
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("r","g","b","a"); }
    }

    public static class VkImageSubresourceRange extends Structure {
        public int aspectMask;
        public int baseMipLevel;
        public int levelCount;
        public int baseArrayLayer;
        public int layerCount;
        public VkImageSubresourceRange(){}
        public VkImageSubresourceRange(int aspect,int baseMip,int levelCount,int baseLayer,int layerCount){
            this.aspectMask=aspect; this.baseMipLevel=baseMip; this.levelCount=levelCount; this.baseArrayLayer=baseLayer; this.layerCount=layerCount;
        }
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("aspectMask","baseMipLevel","levelCount","baseArrayLayer","layerCount"); }
    }

    public static class VkImageViewCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public long image; // VkImage
        public int viewType;
        public int format;
        public VkComponentMapping components = new VkComponentMapping();
        public VkImageSubresourceRange subresourceRange = new VkImageSubresourceRange();

        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","image","viewType","format","components","subresourceRange");
        }
    }

    public static class VkAttachmentDescription extends Structure {
        public int flags;
        public int format;
        public int samples;
        public int loadOp;
        public int storeOp;
        public int stencilLoadOp;
        public int stencilStoreOp;
        public int initialLayout;
        public int finalLayout;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("flags","format","samples","loadOp","storeOp","stencilLoadOp","stencilStoreOp","initialLayout","finalLayout");
        }
    }

    public static class VkAttachmentReference extends Structure {
        public int attachment;
        public int layout;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("attachment","layout"); }
    }

    public static class VkSubpassDescription extends Structure {
        public int flags;
        public int pipelineBindPoint;
        public int inputAttachmentCount;
        public Pointer pInputAttachments;
        public int colorAttachmentCount;
        public Pointer pColorAttachments; // VkAttachmentReference*
        public Pointer pResolveAttachments;
        public Pointer pDepthStencilAttachment;
        public int preserveAttachmentCount;
        public Pointer pPreserveAttachments;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("flags","pipelineBindPoint","inputAttachmentCount","pInputAttachments","colorAttachmentCount",
                    "pColorAttachments","pResolveAttachments","pDepthStencilAttachment","preserveAttachmentCount","pPreserveAttachments");
        }
    }

    public static class VkRenderPassCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public int attachmentCount;
        public Pointer pAttachments; // VkAttachmentDescription*
        public int subpassCount;
        public Pointer pSubpasses; // VkSubpassDescription*
        public int dependencyCount;
        public Pointer pDependencies;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","attachmentCount","pAttachments","subpassCount","pSubpasses","dependencyCount","pDependencies");
        }
    }

    public static class VkShaderModuleCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public long codeSize;
        public Pointer pCode;   // uint32_t*

        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","codeSize","pCode");
        }
    }

    public static class VkPipelineShaderStageCreateInfo extends Structure {
        public int sType;
        public Pointer pNext;
        public int flags;
        public int stage;
        public long module; // VkShaderModule
        public Pointer pName; // char*
        public Pointer pSpecializationInfo;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","stage","module","pName","pSpecializationInfo");
        }
    }

    public static class VkPipelineVertexInputStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int vertexBindingDescriptionCount; public Pointer pVertexBindingDescriptions;
        public int vertexAttributeDescriptionCount; public Pointer pVertexAttributeDescriptions;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","vertexBindingDescriptionCount","pVertexBindingDescriptions",
                    "vertexAttributeDescriptionCount","pVertexAttributeDescriptions");
        }
    }

    public static class VkPipelineInputAssemblyStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int topology; public int primitiveRestartEnable;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","flags","topology","primitiveRestartEnable"); }
    }

    public static class VkViewport extends Structure {
        public float x,y,width,height,minDepth,maxDepth;
        public VkViewport(){}
        public VkViewport(float x,float y,float w,float h,float minD,float maxD){this.x=x;this.y=y;this.width=w;this.height=h;this.minDepth=minD;this.maxDepth=maxD;}
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("x","y","width","height","minDepth","maxDepth"); }
    }

    public static class VkOffset2D extends Structure {
        public int x,y;
        public VkOffset2D(){}
        public VkOffset2D(int x,int y){this.x=x;this.y=y;}
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("x","y"); }
    }

    public static class VkRect2D extends Structure {
        public VkOffset2D offset = new VkOffset2D();
        public VkExtent2D extent = new VkExtent2D();
        public VkRect2D(){}
        public VkRect2D(VkOffset2D off, VkExtent2D ex){offset=off; extent=ex;}
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("offset","extent"); }
    }

    public static class VkPipelineViewportStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int viewportCount; public Pointer pViewports; // VkViewport*
        public int scissorCount; public Pointer pScissors;  // VkRect2D*
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","viewportCount","pViewports","scissorCount","pScissors");
        }
    }

    public static class VkPipelineRasterizationStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int depthClampEnable;
        public int rasterizerDiscardEnable;
        public int polygonMode;
        public int cullMode;
        public int frontFace;
        public int depthBiasEnable;
        public float depthBiasConstantFactor;
        public float depthBiasClamp;
        public float depthBiasSlopeFactor;
        public float lineWidth;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","depthClampEnable","rasterizerDiscardEnable","polygonMode",
                    "cullMode","frontFace","depthBiasEnable","depthBiasConstantFactor","depthBiasClamp","depthBiasSlopeFactor","lineWidth");
        }
    }

    public static class VkPipelineMultisampleStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int rasterizationSamples;
        public int sampleShadingEnable;
        public float minSampleShading;
        public Pointer pSampleMask;
        public int alphaToCoverageEnable;
        public int alphaToOneEnable;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","rasterizationSamples","sampleShadingEnable","minSampleShading",
                    "pSampleMask","alphaToCoverageEnable","alphaToOneEnable");
        }
    }

    public static class VkPipelineColorBlendAttachmentState extends Structure {
        public int blendEnable;
        public int srcColorBlendFactor;
        public int dstColorBlendFactor;
        public int colorBlendOp;
        public int srcAlphaBlendFactor;
        public int dstAlphaBlendFactor;
        public int alphaBlendOp;
        public int colorWriteMask;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("blendEnable","srcColorBlendFactor","dstColorBlendFactor","colorBlendOp",
                    "srcAlphaBlendFactor","dstAlphaBlendFactor","alphaBlendOp","colorWriteMask");
        }
    }

    public static class VkPipelineColorBlendStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int logicOpEnable;
        public int logicOp;
        public int attachmentCount;
        public Pointer pAttachments; // VkPipelineColorBlendAttachmentState*
        public float[] blendConstants = new float[4];
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","logicOpEnable","logicOp","attachmentCount","pAttachments","blendConstants");
        }
    }

    public static class VkDynamicStateCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int dynamicStateCount;
        public Pointer pDynamicStates; // uint32*
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","flags","dynamicStateCount","pDynamicStates"); }
    }

    public static class VkPipelineLayoutCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int setLayoutCount; public Pointer pSetLayouts;
        public int pushConstantRangeCount; public Pointer pPushConstantRanges;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","setLayoutCount","pSetLayouts","pushConstantRangeCount","pPushConstantRanges");
        }
    }

    public static class VkGraphicsPipelineCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public int stageCount; public Pointer pStages; // VkPipelineShaderStageCreateInfo*
        public Pointer pVertexInputState;
        public Pointer pInputAssemblyState;
        public Pointer pTessellationState;
        public Pointer pViewportState;
        public Pointer pRasterizationState;
        public Pointer pMultisampleState;
        public Pointer pDepthStencilState;
        public Pointer pColorBlendState;
        public Pointer pDynamicState;
        public long layout;     // VkPipelineLayout
        public long renderPass; // VkRenderPass
        public int subpass;
        public long basePipelineHandle;
        public int basePipelineIndex;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","stageCount","pStages","pVertexInputState","pInputAssemblyState",
                    "pTessellationState","pViewportState","pRasterizationState","pMultisampleState","pDepthStencilState",
                    "pColorBlendState","pDynamicState","layout","renderPass","subpass","basePipelineHandle","basePipelineIndex");
        }
    }

    public static class VkFramebufferCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        public long renderPass;
        public int attachmentCount;
        public Pointer pAttachments; // VkImageView*
        public int width, height, layers;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","flags","renderPass","attachmentCount","pAttachments","width","height","layers");
        }
    }

    public static class VkCommandPoolCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags; public int queueFamilyIndex;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","flags","queueFamilyIndex"); }
    }

    public static class VkCommandBufferAllocateInfo extends Structure {
        public int sType; public Pointer pNext;
        public Pointer commandPool; // VkCommandPool (dispatchable)
        public int level;
        public int commandBufferCount;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","commandPool","level","commandBufferCount"); }
    }

    public static class VkCommandBufferBeginInfo extends Structure {
        public int sType; public Pointer pNext; public int flags; public Pointer pInheritanceInfo;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","flags","pInheritanceInfo"); }
    }

    public static class VkClearColorValue extends Structure {
        public float[] float32 = new float[4];
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("float32"); }
    }

    public static class VkClearValue extends Union {
        public VkClearColorValue color;
    }

    public static class VkRenderPassBeginInfo extends Structure {
        public int sType; public Pointer pNext;
        public long renderPass;
        public long framebuffer;
        public VkRect2D renderArea = new VkRect2D();
        public int clearValueCount;
        public Pointer pClearValues; // VkClearValue*
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","renderPass","framebuffer","renderArea","clearValueCount","pClearValues");
        }
    }

    public static class VkSemaphoreCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","flags"); }
    }

    public static class VkFenceCreateInfo extends Structure {
        public int sType; public Pointer pNext; public int flags;
        @Override protected List<String> getFieldOrder(){ return Arrays.asList("sType","pNext","flags"); }
    }

    public static class VkSubmitInfo extends Structure {
        public int sType; public Pointer pNext;
        public int waitSemaphoreCount;
        public Pointer pWaitSemaphores; // VkSemaphore*
        public Pointer pWaitDstStageMask; // uint32*
        public int commandBufferCount;
        public Pointer pCommandBuffers; // VkCommandBuffer*
        public int signalSemaphoreCount;
        public Pointer pSignalSemaphores; // VkSemaphore*
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","waitSemaphoreCount","pWaitSemaphores","pWaitDstStageMask",
                    "commandBufferCount","pCommandBuffers","signalSemaphoreCount","pSignalSemaphores");
        }
    }

    public static class VkPresentInfoKHR extends Structure {
        public int sType; public Pointer pNext;
        public int waitSemaphoreCount;
        public Pointer pWaitSemaphores; // VkSemaphore*
        public int swapchainCount;
        public Pointer pSwapchains; // VkSwapchainKHR*
        public Pointer pImageIndices; // uint32*
        public Pointer pResults;
        @Override protected List<String> getFieldOrder(){
            return Arrays.asList("sType","pNext","waitSemaphoreCount","pWaitSemaphores","swapchainCount","pSwapchains","pImageIndices","pResults");
        }
    }

    // ------------------------------------------------------------
    // Vulkan state
    // ------------------------------------------------------------
    static Pointer instance;
    static long surface;
    static Pointer physicalDevice;
    static Pointer device;
    static Pointer graphicsQueue;
    static Pointer presentQueue;

    static int graphicsQueueFamily = -1;
    static int presentQueueFamily  = -1;

    // swapchain bundle
    static long swapchain;
    static int swapchainFormat;
    static VkExtent2D swapchainExtent = new VkExtent2D();
    static int swapchainImageCount;
    static long[] swapchainImages;
    static long[] swapchainImageViews;

    static long renderPass;
    static long pipelineLayout;
    static long pipeline;
    static long[] framebuffers;

    static Pointer commandPool;
    static Pointer[] commandBuffers;

    // sync
    static final int MAX_FRAMES_IN_FLIGHT = 2;
    static long[] imageAvailable = new long[MAX_FRAMES_IN_FLIGHT];
    static long[] renderFinished = new long[MAX_FRAMES_IN_FLIGHT];
    static long[] inFlightFences = new long[MAX_FRAMES_IN_FLIGHT];
    static int frameIndex = 0;

    static boolean resized = false;

    // Device functions used in loop
    static Function vkAcquireNextImageKHR;
    static Function vkQueueSubmit;
    static Function vkQueuePresentKHR;
    static Function vkWaitForFences;
    static Function vkResetFences;
    static Function vkDeviceWaitIdle;

    // ------------------------------------------------------------
    // Entry
    // ------------------------------------------------------------
    public static void main(String[] args) throws Exception {
        // SWT window
        Display display = new Display();
        Shell shell = new Shell(display);
        shell.setText("Vulkan 1.4 Triangle (Java17 + SWT + JNA)");
        shell.setSize(800, 600);

        shell.addListener(SWT.Resize, e -> resized = true);
        shell.addListener(SWT.Dispose, e -> { /* cleanup handled after loop */ });

        shell.open();

        long hwndVal = shell.handle; // Windows SWT
        Pointer hwnd = new Pointer(hwndVal);

        long hinstVal = OS.GetModuleHandle(null);
        Pointer hinst = new Pointer(hinstVal);

        // Load SPIR-V
        byte[] vertSpv = readAllBytes(Paths.get("hello_vert.spv"));
        byte[] fragSpv = readAllBytes(Paths.get("hello_frag.spv"));

        // Init Vulkan
        createInstance();
        createSurface(hwnd, hinst);
        pickPhysicalDeviceAndQueues();
        createDeviceAndQueues();
        loadLoopFunctions();

        createSwapchainBundle(hwnd, vertSpv, fragSpv);
        createSyncObjects();

        // Main loop (SWT event loop)
        while (!shell.isDisposed()) {
            if (!display.readAndDispatch()) {
                renderFrame(hwnd, vertSpv, fragSpv);
                display.sleep();
            }
        }

        // Cleanup
        vkCheck((int)vkDeviceWaitIdle.invokeInt(new Object[]{ device }), "vkDeviceWaitIdle");

        destroySyncObjects();
        destroySwapchainBundle();
        destroyDeviceSurfaceInstance();

        display.dispose();
        System.out.println("Done.");
    }

    // ------------------------------------------------------------
    // Instance / surface / device
    // ------------------------------------------------------------
    static void createInstance() {
        Function vkCreateInstance = vkGlobal("vkCreateInstance");

        VkApplicationInfo app = new VkApplicationInfo();
        app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        app.pNext = null;
        Memory appName = utf8z("JavaVulkanTriangle");
        Memory engName = utf8z("NoEngine");
        app.pApplicationName = appName;
        app.applicationVersion = 1;
        app.pEngineName = engName;
        app.engineVersion = 1;
        app.apiVersion = VK_API_VERSION_1_4;
        app.write();

        // extensions
        Memory ext1 = utf8z(VK_KHR_SURFACE_EXTENSION_NAME);
        Memory ext2 = utf8z(VK_KHR_WIN32_SURFACE_EXTENSION_NAME);

        Memory ppExt = new Memory(Native.POINTER_SIZE * 2L);
        ppExt.setPointer(0, ext1);
        ppExt.setPointer(Native.POINTER_SIZE, ext2);

        VkInstanceCreateInfo ici = new VkInstanceCreateInfo();
        ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        ici.pNext = null;
        ici.flags = 0;
        ici.pApplicationInfo = app.getPointer();
        ici.enabledLayerCount = 0;
        ici.ppEnabledLayerNames = null;
        ici.enabledExtensionCount = 2;
        ici.ppEnabledExtensionNames = ppExt;
        ici.write();

        PointerByReference pInst = new PointerByReference();
        int res = vkCreateInstance.invokeInt(new Object[]{ ici.getPointer(), Pointer.NULL, pInst });
        vkCheck(res, "vkCreateInstance");

        instance = pInst.getValue();
        System.out.println("vkCreateInstance OK: " + instance);
    }

    static void createSurface(Pointer hwnd, Pointer hinst) {
        Function vkCreateWin32SurfaceKHR = vkInst(instance, "vkCreateWin32SurfaceKHR");

        VkWin32SurfaceCreateInfoKHR sci = new VkWin32SurfaceCreateInfoKHR();
        sci.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        sci.pNext = null;
        sci.flags = 0;
        sci.hinstance = hinst;
        sci.hwnd = hwnd;
        sci.write();

        LongByReference pSurface = new LongByReference();
        int res = vkCreateWin32SurfaceKHR.invokeInt(new Object[]{ instance, sci.getPointer(), Pointer.NULL, pSurface });
        vkCheck(res, "vkCreateWin32SurfaceKHR");

        surface = pSurface.getValue();
        System.out.println("vkCreateWin32SurfaceKHR OK: surface=" + Long.toHexString(surface));
    }

    static void pickPhysicalDeviceAndQueues() {
        Function vkEnumeratePhysicalDevices = vkGlobal("vkEnumeratePhysicalDevices");
        Function vkGetPhysicalDeviceQueueFamilyProperties = vkGlobal("vkGetPhysicalDeviceQueueFamilyProperties");
        Function vkGetPhysicalDeviceSurfaceSupportKHR = vkInst(instance, "vkGetPhysicalDeviceSurfaceSupportKHR");

        IntByReference pCount = new IntByReference(0);
        vkCheck(vkEnumeratePhysicalDevices.invokeInt(new Object[]{ instance, pCount, Pointer.NULL }), "vkEnumeratePhysicalDevices(count)");
        int count = pCount.getValue();
        if (count <= 0) throw new RuntimeException("No Vulkan physical devices found.");

        Memory devs = new Memory(Native.POINTER_SIZE * (long)count);
        vkCheck(vkEnumeratePhysicalDevices.invokeInt(new Object[]{ instance, pCount, devs }), "vkEnumeratePhysicalDevices(list)");

        for (int i = 0; i < count; i++) {
            Pointer pd = devs.getPointer((long)i * Native.POINTER_SIZE);

            IntByReference qCount = new IntByReference(0);
            vkGetPhysicalDeviceQueueFamilyProperties.invokeVoid(new Object[]{ pd, qCount, Pointer.NULL });
            int qc = qCount.getValue();
            if (qc <= 0) continue;

            VkQueueFamilyProperties props = new VkQueueFamilyProperties();
            props.write();
            Memory propsBuf = new Memory((long)props.size() * qc);
            vkGetPhysicalDeviceQueueFamilyProperties.invokeVoid(new Object[]{ pd, qCount, propsBuf });

            int gIdx = -1;
            int pIdx = -1;

            for (int qi = 0; qi < qc; qi++) {
                VkQueueFamilyProperties qfp = new VkQueueFamilyProperties(propsBuf.share((long)props.size() * qi));
                qfp.read();

                if ((qfp.queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0) gIdx = qi;

                IntByReference supported = new IntByReference(0);
                int r = vkGetPhysicalDeviceSurfaceSupportKHR.invokeInt(new Object[]{ pd, qi, surface, supported });
                vkCheck(r, "vkGetPhysicalDeviceSurfaceSupportKHR");
                if (supported.getValue() != 0) pIdx = qi;

                if (gIdx != -1 && pIdx != -1) {
                    physicalDevice = pd;
                    graphicsQueueFamily = gIdx;
                    presentQueueFamily = pIdx;
                    System.out.println("Selected physical device: " + pd + " graphicsQ=" + gIdx + " presentQ=" + pIdx);
                    return;
                }
            }
        }
        throw new RuntimeException("No suitable device/queue found.");
    }

    static void createDeviceAndQueues() {
        Function vkCreateDevice = vkGlobal("vkCreateDevice");

        // unique queue families
        int[] qf = (graphicsQueueFamily == presentQueueFamily)
                ? new int[]{ graphicsQueueFamily }
                : new int[]{ graphicsQueueFamily, presentQueueFamily };

        // priorities float[1]
        Memory prio = new Memory(4);
        prio.setFloat(0, 1.0f);

        VkDeviceQueueCreateInfo qci0 = new VkDeviceQueueCreateInfo();
        VkDeviceQueueCreateInfo qci1 = new VkDeviceQueueCreateInfo();
        VkDeviceQueueCreateInfo[] qcis = (qf.length == 1) ? new VkDeviceQueueCreateInfo[]{ qci0 } : new VkDeviceQueueCreateInfo[]{ qci0, qci1 };

        Memory qciBuf = new Memory((long)qci0.size() * qcis.length);

        for (int i = 0; i < qcis.length; i++) {
            VkDeviceQueueCreateInfo qci = new VkDeviceQueueCreateInfo(qciBuf.share((long)qci0.size() * i));
            qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            qci.pNext = null;
            qci.flags = 0;
            qci.queueFamilyIndex = qf[i];
            qci.queueCount = 1;
            qci.pQueuePriorities = prio;
            qci.write();
        }

        // device extensions (swapchain)
        Memory ext = utf8z(VK_KHR_SWAPCHAIN_EXTENSION_NAME);
        Memory ppExt = new Memory(Native.POINTER_SIZE);
        ppExt.setPointer(0, ext);

        VkDeviceCreateInfo dci = new VkDeviceCreateInfo();
        dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        dci.pNext = null;
        dci.flags = 0;
        dci.queueCreateInfoCount = qcis.length;
        dci.pQueueCreateInfos = qciBuf;
        dci.enabledLayerCount = 0;
        dci.ppEnabledLayerNames = null;
        dci.enabledExtensionCount = 1;
        dci.ppEnabledExtensionNames = ppExt;
        dci.pEnabledFeatures = null;
        dci.write();

        PointerByReference pDev = new PointerByReference();
        vkCheck(vkCreateDevice.invokeInt(new Object[]{ physicalDevice, dci.getPointer(), Pointer.NULL, pDev }), "vkCreateDevice");
        device = pDev.getValue();
        System.out.println("vkCreateDevice OK: " + device);

        Function vkGetDeviceQueue = vkDev(device, "vkGetDeviceQueue");

        PointerByReference pGQ = new PointerByReference();
        PointerByReference pPQ = new PointerByReference();

        vkGetDeviceQueue.invokeVoid(new Object[]{ device, graphicsQueueFamily, 0, pGQ });
        vkGetDeviceQueue.invokeVoid(new Object[]{ device, presentQueueFamily,  0, pPQ });

        graphicsQueue = pGQ.getValue();
        presentQueue  = pPQ.getValue();
        System.out.println("Queues: graphics=" + graphicsQueue + " present=" + presentQueue);
    }

    static void loadLoopFunctions() {
        vkAcquireNextImageKHR = vkDev(device, "vkAcquireNextImageKHR");
        vkQueueSubmit         = vkDev(device, "vkQueueSubmit");
        vkQueuePresentKHR     = vkDev(device, "vkQueuePresentKHR");
        vkWaitForFences       = vkDev(device, "vkWaitForFences");
        vkResetFences         = vkDev(device, "vkResetFences");
        vkDeviceWaitIdle      = vkDev(device, "vkDeviceWaitIdle");
    }

    // ------------------------------------------------------------
    // Swapchain bundle
    // ------------------------------------------------------------
    static void createSwapchainBundle(Pointer hwnd, byte[] vertSpv, byte[] fragSpv) {
        Function vkGetPhysicalDeviceSurfaceCapabilitiesKHR = vkInst(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
        Function vkGetPhysicalDeviceSurfaceFormatsKHR      = vkInst(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR");
        Function vkGetPhysicalDeviceSurfacePresentModesKHR = vkInst(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR");

        VkSurfaceCapabilitiesKHR caps = new VkSurfaceCapabilitiesKHR();
        caps.write();
        vkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR.invokeInt(new Object[]{ physicalDevice, surface, caps.getPointer() }),
                "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
        caps.read();

        IntByReference fmtCount = new IntByReference(0);
        vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR.invokeInt(new Object[]{ physicalDevice, surface, fmtCount, Pointer.NULL }),
                "vkGetPhysicalDeviceSurfaceFormatsKHR(count)");
        int fc = fmtCount.getValue();
        if (fc <= 0) throw new RuntimeException("No surface formats.");

        VkSurfaceFormatKHR fmt0 = new VkSurfaceFormatKHR();
        Memory fmtsBuf = new Memory((long)fmt0.size() * fc);
        vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR.invokeInt(new Object[]{ physicalDevice, surface, fmtCount, fmtsBuf }),
                "vkGetPhysicalDeviceSurfaceFormatsKHR(list)");

        // Prefer VK_FORMAT_B8G8R8A8_UNORM (44)
        int chosenFormat = -1;
        int chosenColorSpace = -1;
        for (int i = 0; i < fc; i++) {
            VkSurfaceFormatKHR f = new VkSurfaceFormatKHR(fmtsBuf.share((long)fmt0.size() * i));
            f.read();
            if (f.format == 44) { chosenFormat = f.format; chosenColorSpace = f.colorSpace; break; }
            if (chosenFormat == -1) { chosenFormat = f.format; chosenColorSpace = f.colorSpace; }
        }

        int w = shellClientWidth(hwnd);
        int h = shellClientHeight(hwnd);

        int extentW = caps.currentExtent.width;
        int extentH = caps.currentExtent.height;
        if (extentW == 0xFFFFFFFF || extentH == 0xFFFFFFFF) {
            extentW = clamp(w, caps.minImageExtent.width, caps.maxImageExtent.width);
            extentH = clamp(h, caps.minImageExtent.height, caps.maxImageExtent.height);
        }

        swapchainFormat = chosenFormat;
        swapchainExtent = new VkExtent2D(extentW, extentH);

        int imageCount = caps.minImageCount + 1;
        if (caps.maxImageCount != 0 && imageCount > caps.maxImageCount) imageCount = caps.maxImageCount;

        // create swapchain
        Function vkCreateSwapchainKHR = vkDev(device, "vkCreateSwapchainKHR");
        Function vkGetSwapchainImagesKHR = vkDev(device, "vkGetSwapchainImagesKHR");

        VkSwapchainCreateInfoKHR sci = new VkSwapchainCreateInfoKHR();
        sci.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        sci.pNext = null;
        sci.flags = 0;
        sci.surface = surface;
        sci.minImageCount = imageCount;
        sci.imageFormat = chosenFormat;
        sci.imageColorSpace = chosenColorSpace;
        sci.imageExtent = swapchainExtent;
        sci.imageArrayLayers = 1;
        sci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        if (graphicsQueueFamily != presentQueueFamily) {
            sci.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
            sci.queueFamilyIndexCount = 2;
            Memory qidx = new Memory(4 * 2L);
            qidx.setInt(0, graphicsQueueFamily);
            qidx.setInt(4, presentQueueFamily);
            sci.pQueueFamilyIndices = qidx;
        } else {
            sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
            sci.queueFamilyIndexCount = 0;
            sci.pQueueFamilyIndices = null;
        }

        sci.preTransform = (caps.supportedTransforms & caps.currentTransform) != 0 ? caps.currentTransform : VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        sci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        sci.presentMode = VK_PRESENT_MODE_FIFO_KHR;
        sci.clipped = 1;
        sci.oldSwapchain = 0;
        sci.write();

        LongByReference pSc = new LongByReference();
        vkCheck(vkCreateSwapchainKHR.invokeInt(new Object[]{ device, sci.getPointer(), Pointer.NULL, pSc }), "vkCreateSwapchainKHR");
        swapchain = pSc.getValue();

        IntByReference imgCount = new IntByReference(0);
        vkCheck(vkGetSwapchainImagesKHR.invokeInt(new Object[]{ device, swapchain, imgCount, Pointer.NULL }), "vkGetSwapchainImagesKHR(count)");
        swapchainImageCount = imgCount.getValue();
        Memory imgsBuf = new Memory(8L * swapchainImageCount); // VkImage = uint64
        vkCheck(vkGetSwapchainImagesKHR.invokeInt(new Object[]{ device, swapchain, imgCount, imgsBuf }), "vkGetSwapchainImagesKHR(list)");

        swapchainImages = new long[swapchainImageCount];
        for (int i = 0; i < swapchainImageCount; i++) swapchainImages[i] = imgsBuf.getLong(8L * i);

        System.out.println("Swapchain: images=" + swapchainImageCount + " extent=" + swapchainExtent.width + "x" + swapchainExtent.height);

        createImageViews();
        createRenderPass();
        createPipeline(vertSpv, fragSpv);
        createFramebuffers();
        createCommandPoolAndBuffers();
        recordCommandBuffers();
    }

    static int shellClientWidth(Pointer hwnd) {
        return 800;
    }
    static int shellClientHeight(Pointer hwnd) { return 600; }

    static int clamp(int v, int lo, int hi) { return Math.max(lo, Math.min(hi, v)); }

    static void destroySwapchainBundle() {
        if (device == null) return;

        Function vkDestroyCommandPool    = vkDev(device, "vkDestroyCommandPool");
        Function vkDestroyFramebuffer    = vkDev(device, "vkDestroyFramebuffer");
        Function vkDestroyPipeline       = vkDev(device, "vkDestroyPipeline");
        Function vkDestroyPipelineLayout = vkDev(device, "vkDestroyPipelineLayout");
        Function vkDestroyRenderPass     = vkDev(device, "vkDestroyRenderPass");
        Function vkDestroyImageView      = vkDev(device, "vkDestroyImageView");
        Function vkDestroySwapchainKHR   = vkDev(device, "vkDestroySwapchainKHR");

        if (commandPool != null && Pointer.nativeValue(commandPool) != 0) {
            vkDestroyCommandPool.invokeVoid(new Object[]{ device, commandPool, Pointer.NULL });
            commandPool = null;
        }

        if (framebuffers != null) {
            for (long fb : framebuffers) if (fb != 0) vkDestroyFramebuffer.invokeVoid(new Object[]{ device, fb, Pointer.NULL });
            framebuffers = null;
        }

        if (pipeline != 0) vkDestroyPipeline.invokeVoid(new Object[]{ device, pipeline, Pointer.NULL });
        if (pipelineLayout != 0) vkDestroyPipelineLayout.invokeVoid(new Object[]{ device, pipelineLayout, Pointer.NULL });
        if (renderPass != 0) vkDestroyRenderPass.invokeVoid(new Object[]{ device, renderPass, Pointer.NULL });

        if (swapchainImageViews != null) {
            for (long v : swapchainImageViews) if (v != 0) vkDestroyImageView.invokeVoid(new Object[]{ device, v, Pointer.NULL });
            swapchainImageViews = null;
        }

        if (swapchain != 0) vkDestroySwapchainKHR.invokeVoid(new Object[]{ device, swapchain, Pointer.NULL });
        swapchain = 0;
    }

    static void recreateSwapchain(Pointer hwnd, byte[] vertSpv, byte[] fragSpv) {
        System.out.println("Recreate swapchain...");
        vkCheck((int)vkDeviceWaitIdle.invokeInt(new Object[]{ device }), "vkDeviceWaitIdle");
        destroySwapchainBundle();
        createSwapchainBundle(hwnd, vertSpv, fragSpv);
    }

    static void createImageViews() {
        Function vkCreateImageView = vkDev(device, "vkCreateImageView");

        swapchainImageViews = new long[swapchainImageCount];
        for (int i = 0; i < swapchainImageCount; i++) {
            VkImageViewCreateInfo iv = new VkImageViewCreateInfo();
            iv.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            iv.pNext = null;
            iv.flags = 0;
            iv.image = swapchainImages[i];
            iv.viewType = VK_IMAGE_VIEW_TYPE_2D;
            iv.format = swapchainFormat;
            iv.components = new VkComponentMapping(0,0,0,0);
            iv.subresourceRange = new VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1);
            iv.write();

            LongByReference pView = new LongByReference();
            vkCheck(vkCreateImageView.invokeInt(new Object[]{ device, iv.getPointer(), Pointer.NULL, pView }), "vkCreateImageView");
            swapchainImageViews[i] = pView.getValue();
        }
    }

    static void createRenderPass() {
        Function vkCreateRenderPass = vkDev(device, "vkCreateRenderPass");

        VkAttachmentDescription color = new VkAttachmentDescription();
        color.flags = 0;
        color.format = swapchainFormat;
        color.samples = VK_SAMPLE_COUNT_1_BIT;
        color.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        color.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        color.stencilLoadOp = 0;
        color.stencilStoreOp = 0;
        color.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        color.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        color.write();

        VkAttachmentReference ref = new VkAttachmentReference();
        ref.attachment = 0;
        ref.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        ref.write();

        VkSubpassDescription sub = new VkSubpassDescription();
        sub.flags = 0;
        sub.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
        sub.inputAttachmentCount = 0;
        sub.pInputAttachments = null;
        sub.colorAttachmentCount = 1;
        sub.pColorAttachments = ref.getPointer();
        sub.pResolveAttachments = null;
        sub.pDepthStencilAttachment = null;
        sub.preserveAttachmentCount = 0;
        sub.pPreserveAttachments = null;
        sub.write();

        VkRenderPassCreateInfo rpci = new VkRenderPassCreateInfo();
        rpci.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        rpci.pNext = null;
        rpci.flags = 0;
        rpci.attachmentCount = 1;
        rpci.pAttachments = color.getPointer();
        rpci.subpassCount = 1;
        rpci.pSubpasses = sub.getPointer();
        rpci.dependencyCount = 0;
        rpci.pDependencies = null;
        rpci.write();

        LongByReference pRp = new LongByReference();
        vkCheck(vkCreateRenderPass.invokeInt(new Object[]{ device, rpci.getPointer(), Pointer.NULL, pRp }), "vkCreateRenderPass");
        renderPass = pRp.getValue();
    }

    static long createShaderModule(byte[] spv) {
        Function vkCreateShaderModule = vkDev(device, "vkCreateShaderModule");

        if ((spv.length % 4) != 0) throw new RuntimeException("SPIR-V size must be multiple of 4");

        Memory code = new Memory(spv.length);
        code.write(0, spv, 0, spv.length);

        VkShaderModuleCreateInfo smci = new VkShaderModuleCreateInfo();
        smci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        smci.pNext = null;
        smci.flags = 0;
        smci.codeSize = spv.length;
        smci.pCode = code;
        smci.write();

        LongByReference pMod = new LongByReference();
        vkCheck(vkCreateShaderModule.invokeInt(new Object[]{ device, smci.getPointer(), Pointer.NULL, pMod }), "vkCreateShaderModule");
        return pMod.getValue();
    }

    static void createPipeline(byte[] vertSpv, byte[] fragSpv) {
        Function vkCreatePipelineLayout = vkDev(device, "vkCreatePipelineLayout");
        Function vkCreateGraphicsPipelines = vkDev(device, "vkCreateGraphicsPipelines");
        Function vkDestroyShaderModule = vkDev(device, "vkDestroyShaderModule");

        long vert = createShaderModule(vertSpv);
        long frag = createShaderModule(fragSpv);

        VkPipelineLayoutCreateInfo plci = new VkPipelineLayoutCreateInfo();
        plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        plci.pNext = null;
        plci.flags = 0;
        plci.setLayoutCount = 0;
        plci.pSetLayouts = null;
        plci.pushConstantRangeCount = 0;
        plci.pPushConstantRanges = null;
        plci.write();

        LongByReference pPL = new LongByReference();
        vkCheck(vkCreatePipelineLayout.invokeInt(new Object[]{ device, plci.getPointer(), Pointer.NULL, pPL }), "vkCreatePipelineLayout");
        pipelineLayout = pPL.getValue();

        Memory entry = utf8z("main");

        VkPipelineShaderStageCreateInfo vs = new VkPipelineShaderStageCreateInfo();
        vs.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vs.pNext = null;
        vs.flags = 0;
        vs.stage = VK_SHADER_STAGE_VERTEX_BIT;
        vs.module = vert;
        vs.pName = entry;
        vs.pSpecializationInfo = null;
        vs.write();

        VkPipelineShaderStageCreateInfo fs = new VkPipelineShaderStageCreateInfo();
        fs.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fs.pNext = null;
        fs.flags = 0;
        fs.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        fs.module = frag;
        fs.pName = entry;
        fs.pSpecializationInfo = null;
        fs.write();

        Memory stages = new Memory(vs.size() * 2L);
        vs.getPointer().read(0, stages.getByteArray(0, vs.size()), 0, vs.size()); // not used
        // safer: write both structs into a contiguous buffer
        vs.write(); fs.write();
        stages.write(0, vs.getPointer().getByteArray(0, vs.size()), 0, vs.size());
        stages.write(vs.size(), fs.getPointer().getByteArray(0, fs.size()), 0, fs.size());

        VkPipelineVertexInputStateCreateInfo vin = new VkPipelineVertexInputStateCreateInfo();
        vin.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
        vin.pNext = null;
        vin.flags = 0;
        vin.vertexBindingDescriptionCount = 0;
        vin.pVertexBindingDescriptions = null;
        vin.vertexAttributeDescriptionCount = 0;
        vin.pVertexAttributeDescriptions = null;
        vin.write();

        VkPipelineInputAssemblyStateCreateInfo ia = new VkPipelineInputAssemblyStateCreateInfo();
        ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        ia.pNext = null;
        ia.flags = 0;
        ia.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        ia.primitiveRestartEnable = 0;
        ia.write();

        VkViewport dummyVP = new VkViewport(0,0, swapchainExtent.width, swapchainExtent.height, 0,1);
        dummyVP.write();
        VkRect2D dummySC = new VkRect2D(new VkOffset2D(0,0), swapchainExtent);
        dummySC.write();

        VkPipelineViewportStateCreateInfo vp = new VkPipelineViewportStateCreateInfo();
        vp.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        vp.pNext = null;
        vp.flags = 0;
        vp.viewportCount = 1;
        vp.pViewports = dummyVP.getPointer();
        vp.scissorCount = 1;
        vp.pScissors = dummySC.getPointer();
        vp.write();

        VkPipelineRasterizationStateCreateInfo rs = new VkPipelineRasterizationStateCreateInfo();
        rs.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rs.pNext = null;
        rs.flags = 0;
        rs.depthClampEnable = 0;
        rs.rasterizerDiscardEnable = 0;
        rs.polygonMode = VK_POLYGON_MODE_FILL;
        rs.cullMode = VK_CULL_MODE_NONE;
        rs.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rs.depthBiasEnable = 0;
        rs.depthBiasConstantFactor = 0;
        rs.depthBiasClamp = 0;
        rs.depthBiasSlopeFactor = 0;
        rs.lineWidth = 1.0f;
        rs.write();

        VkPipelineMultisampleStateCreateInfo ms = new VkPipelineMultisampleStateCreateInfo();
        ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        ms.pNext = null;
        ms.flags = 0;
        ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
        ms.sampleShadingEnable = 0;
        ms.minSampleShading = 1.0f;
        ms.pSampleMask = null;
        ms.alphaToCoverageEnable = 0;
        ms.alphaToOneEnable = 0;
        ms.write();

        VkPipelineColorBlendAttachmentState cbAttach = new VkPipelineColorBlendAttachmentState();
        cbAttach.blendEnable = 0;
        cbAttach.srcColorBlendFactor = 0;
        cbAttach.dstColorBlendFactor = 0;
        cbAttach.colorBlendOp = 0;
        cbAttach.srcAlphaBlendFactor = 0;
        cbAttach.dstAlphaBlendFactor = 0;
        cbAttach.alphaBlendOp = 0;
        cbAttach.colorWriteMask = VK_COLOR_COMPONENT_R_BIT|VK_COLOR_COMPONENT_G_BIT|VK_COLOR_COMPONENT_B_BIT|VK_COLOR_COMPONENT_A_BIT;
        cbAttach.write();

        VkPipelineColorBlendStateCreateInfo cb = new VkPipelineColorBlendStateCreateInfo();
        cb.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        cb.pNext = null;
        cb.flags = 0;
        cb.logicOpEnable = 0;
        cb.logicOp = 0;
        cb.attachmentCount = 1;
        cb.pAttachments = cbAttach.getPointer();
        cb.blendConstants[0]=0; cb.blendConstants[1]=0; cb.blendConstants[2]=0; cb.blendConstants[3]=0;
        cb.write();

        // dynamic viewport/scissor
        Memory dynStates = new Memory(4 * 2L);
        dynStates.setInt(0, VK_DYNAMIC_STATE_VIEWPORT);
        dynStates.setInt(4, VK_DYNAMIC_STATE_SCISSOR);

        VkDynamicStateCreateInfo dyn = new VkDynamicStateCreateInfo();
        dyn.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        dyn.pNext = null;
        dyn.flags = 0;
        dyn.dynamicStateCount = 2;
        dyn.pDynamicStates = dynStates;
        dyn.write();

        VkGraphicsPipelineCreateInfo gp = new VkGraphicsPipelineCreateInfo();
        gp.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        gp.pNext = null;
        gp.flags = 0;
        gp.stageCount = 2;
        gp.pStages = stages;
        gp.pVertexInputState = vin.getPointer();
        gp.pInputAssemblyState = ia.getPointer();
        gp.pTessellationState = null;
        gp.pViewportState = vp.getPointer();
        gp.pRasterizationState = rs.getPointer();
        gp.pMultisampleState = ms.getPointer();
        gp.pDepthStencilState = null;
        gp.pColorBlendState = cb.getPointer();
        gp.pDynamicState = dyn.getPointer();
        gp.layout = pipelineLayout;
        gp.renderPass = renderPass;
        gp.subpass = 0;
        gp.basePipelineHandle = 0;
        gp.basePipelineIndex = -1;
        gp.write();

        LongByReference pPipe = new LongByReference();
        vkCheck(vkCreateGraphicsPipelines.invokeInt(new Object[]{ device, 0L, 1, gp.getPointer(), Pointer.NULL, pPipe }),
                "vkCreateGraphicsPipelines");
        pipeline = pPipe.getValue();

        // destroy shader modules
        vkDestroyShaderModule.invokeVoid(new Object[]{ device, vert, Pointer.NULL });
        vkDestroyShaderModule.invokeVoid(new Object[]{ device, frag, Pointer.NULL });
    }

    static void createFramebuffers() {
        Function vkCreateFramebuffer = vkDev(device, "vkCreateFramebuffer");

        framebuffers = new long[swapchainImageCount];
        for (int i = 0; i < swapchainImageCount; i++) {
            Memory attachments = new Memory(8);
            attachments.setLong(0, swapchainImageViews[i]);

            VkFramebufferCreateInfo fb = new VkFramebufferCreateInfo();
            fb.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            fb.pNext = null;
            fb.flags = 0;
            fb.renderPass = renderPass;
            fb.attachmentCount = 1;
            fb.pAttachments = attachments;
            fb.width = swapchainExtent.width;
            fb.height = swapchainExtent.height;
            fb.layers = 1;
            fb.write();

            LongByReference pFB = new LongByReference();
            vkCheck(vkCreateFramebuffer.invokeInt(new Object[]{ device, fb.getPointer(), Pointer.NULL, pFB }), "vkCreateFramebuffer");
            framebuffers[i] = pFB.getValue();
        }
    }

    static void createCommandPoolAndBuffers() {
        Function vkCreateCommandPool = vkDev(device, "vkCreateCommandPool");
        Function vkAllocateCommandBuffers = vkDev(device, "vkAllocateCommandBuffers");

        VkCommandPoolCreateInfo cpci = new VkCommandPoolCreateInfo();
        cpci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        cpci.pNext = null;
        cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        cpci.queueFamilyIndex = graphicsQueueFamily;
        cpci.write();

        PointerByReference pCP = new PointerByReference();
        vkCheck(vkCreateCommandPool.invokeInt(new Object[]{ device, cpci.getPointer(), Pointer.NULL, pCP }), "vkCreateCommandPool");
        commandPool = pCP.getValue();

        VkCommandBufferAllocateInfo ai = new VkCommandBufferAllocateInfo();
        ai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        ai.pNext = null;
        ai.commandPool = commandPool;
        ai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ai.commandBufferCount = swapchainImageCount;
        ai.write();

        Memory out = new Memory(Native.POINTER_SIZE * (long)swapchainImageCount);
        vkCheck(vkAllocateCommandBuffers.invokeInt(new Object[]{ device, ai.getPointer(), out }), "vkAllocateCommandBuffers");

        commandBuffers = new Pointer[swapchainImageCount];
        for (int i = 0; i < swapchainImageCount; i++) {
            commandBuffers[i] = out.getPointer((long)i * Native.POINTER_SIZE);
        }
    }

    static void recordCommandBuffers() {
        Function vkBeginCommandBuffer = vkDev(device, "vkBeginCommandBuffer");
        Function vkEndCommandBuffer   = vkDev(device, "vkEndCommandBuffer");
        Function vkCmdBeginRenderPass = vkDev(device, "vkCmdBeginRenderPass");
        Function vkCmdEndRenderPass   = vkDev(device, "vkCmdEndRenderPass");
        Function vkCmdBindPipeline    = vkDev(device, "vkCmdBindPipeline");
        Function vkCmdDraw            = vkDev(device, "vkCmdDraw");
        Function vkCmdSetViewport     = vkDev(device, "vkCmdSetViewport");
        Function vkCmdSetScissor      = vkDev(device, "vkCmdSetScissor");

        VkClearColorValue ccv = new VkClearColorValue();
        ccv.float32[0]=0.05f; ccv.float32[1]=0.05f; ccv.float32[2]=0.10f; ccv.float32[3]=1.0f;
        ccv.write();

        VkClearValue cv = new VkClearValue();
        cv.setType(VkClearColorValue.class);
        cv.color = ccv;
        cv.write();

        for (int i = 0; i < swapchainImageCount; i++) {
            VkCommandBufferBeginInfo bi = new VkCommandBufferBeginInfo();
            bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
            bi.pNext = null;
            bi.flags = 0;
            bi.pInheritanceInfo = null;
            bi.write();

            vkCheck(vkBeginCommandBuffer.invokeInt(new Object[]{ commandBuffers[i], bi.getPointer() }), "vkBeginCommandBuffer");

            VkViewport vp = new VkViewport(0,0, swapchainExtent.width, swapchainExtent.height, 0,1);
            vp.write();
            VkRect2D sc = new VkRect2D(new VkOffset2D(0,0), swapchainExtent);
            sc.write();

            VkRenderPassBeginInfo rpbi = new VkRenderPassBeginInfo();
            rpbi.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
            rpbi.pNext = null;
            rpbi.renderPass = renderPass;
            rpbi.framebuffer = framebuffers[i];
            rpbi.renderArea = new VkRect2D(new VkOffset2D(0,0), swapchainExtent);
            rpbi.clearValueCount = 1;
            rpbi.pClearValues = cv.getPointer();
            rpbi.write();

            // contents = 0 (INLINE)
            vkCmdBeginRenderPass.invokeVoid(new Object[]{ commandBuffers[i], rpbi.getPointer(), 0 });
            vkCmdBindPipeline.invokeVoid(new Object[]{ commandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline });
            vkCmdSetViewport.invokeVoid(new Object[]{ commandBuffers[i], 0, 1, vp.getPointer() });
            vkCmdSetScissor.invokeVoid(new Object[]{ commandBuffers[i], 0, 1, sc.getPointer() });
            vkCmdDraw.invokeVoid(new Object[]{ commandBuffers[i], 3, 1, 0, 0 });
            vkCmdEndRenderPass.invokeVoid(new Object[]{ commandBuffers[i] });

            vkCheck(vkEndCommandBuffer.invokeInt(new Object[]{ commandBuffers[i] }), "vkEndCommandBuffer");
        }
    }

    // ------------------------------------------------------------
    // Sync & frame rendering
    // ------------------------------------------------------------
    static void createSyncObjects() {
        Function vkCreateSemaphore = vkDev(device, "vkCreateSemaphore");
        Function vkCreateFence     = vkDev(device, "vkCreateFence");

        VkSemaphoreCreateInfo sci = new VkSemaphoreCreateInfo();
        sci.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        sci.pNext = null;
        sci.flags = 0;
        sci.write();

        VkFenceCreateInfo fci = new VkFenceCreateInfo();
        fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fci.pNext = null;
        fci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
        fci.write();

        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            LongByReference pS1 = new LongByReference();
            vkCheck(vkCreateSemaphore.invokeInt(new Object[]{ device, sci.getPointer(), Pointer.NULL, pS1 }), "vkCreateSemaphore");
            imageAvailable[i] = pS1.getValue();

            LongByReference pS2 = new LongByReference();
            vkCheck(vkCreateSemaphore.invokeInt(new Object[]{ device, sci.getPointer(), Pointer.NULL, pS2 }), "vkCreateSemaphore");
            renderFinished[i] = pS2.getValue();

            LongByReference pF = new LongByReference();
            vkCheck(vkCreateFence.invokeInt(new Object[]{ device, fci.getPointer(), Pointer.NULL, pF }), "vkCreateFence");
            inFlightFences[i] = pF.getValue();
        }
    }

    static void destroySyncObjects() {
        Function vkDestroySemaphore = vkDev(device, "vkDestroySemaphore");
        Function vkDestroyFence     = vkDev(device, "vkDestroyFence");
        for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
            if (imageAvailable[i] != 0) vkDestroySemaphore.invokeVoid(new Object[]{ device, imageAvailable[i], Pointer.NULL });
            if (renderFinished[i] != 0) vkDestroySemaphore.invokeVoid(new Object[]{ device, renderFinished[i], Pointer.NULL });
            if (inFlightFences[i] != 0) vkDestroyFence.invokeVoid(new Object[]{ device, inFlightFences[i], Pointer.NULL });
            imageAvailable[i]=renderFinished[i]=inFlightFences[i]=0;
        }
    }

    static void renderFrame(Pointer hwnd, byte[] vertSpv, byte[] fragSpv) {
        if (resized) {
            resized = false;
            recreateSwapchain(hwnd, vertSpv, fragSpv);
            return;
        }

        int cur = frameIndex % MAX_FRAMES_IN_FLIGHT;

        // wait fence
        Memory fences = new Memory(8);
        fences.setLong(0, inFlightFences[cur]);

        vkCheck(vkWaitForFences.invokeInt(new Object[]{ device, 1, fences, 1, -1L }),
                "vkWaitForFences");
        vkCheck(vkResetFences.invokeInt(new Object[]{ device, 1, fences }), "vkResetFences");

        IntByReference imageIndex = new IntByReference(0);

        int acq = vkAcquireNextImageKHR.invokeInt(new Object[]{
                device, swapchain, -1L, imageAvailable[cur], 0L, imageIndex
        });

        if (acq == VK_ERROR_OUT_OF_DATE_KHR) {
            recreateSwapchain(hwnd, vertSpv, fragSpv);
            return;
        }
        if (acq != VK_SUCCESS && acq != VK_SUBOPTIMAL_KHR) throw new RuntimeException("vkAcquireNextImageKHR failed: " + acq);

        // submit
        Memory waitSems = new Memory(8); waitSems.setLong(0, imageAvailable[cur]);
        Memory signalSems = new Memory(8); signalSems.setLong(0, renderFinished[cur]);
        Memory waitStages = new Memory(4); waitStages.setInt(0, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

        Memory cmdBufs = new Memory(Native.POINTER_SIZE);
        cmdBufs.setPointer(0, commandBuffers[imageIndex.getValue()]);

        VkSubmitInfo si = new VkSubmitInfo();
        si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        si.pNext = null;
        si.waitSemaphoreCount = 1;
        si.pWaitSemaphores = waitSems;
        si.pWaitDstStageMask = waitStages;
        si.commandBufferCount = 1;
        si.pCommandBuffers = cmdBufs;
        si.signalSemaphoreCount = 1;
        si.pSignalSemaphores = signalSems;
        si.write();

        vkCheck(vkQueueSubmit.invokeInt(new Object[]{ graphicsQueue, 1, si.getPointer(), inFlightFences[cur] }),
                "vkQueueSubmit");

        // present
        Memory swapchains = new Memory(8); swapchains.setLong(0, swapchain);
        Memory indices = new Memory(4); indices.setInt(0, imageIndex.getValue());

        VkPresentInfoKHR pi = new VkPresentInfoKHR();
        pi.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        pi.pNext = null;
        pi.waitSemaphoreCount = 1;
        pi.pWaitSemaphores = signalSems;
        pi.swapchainCount = 1;
        pi.pSwapchains = swapchains;
        pi.pImageIndices = indices;
        pi.pResults = null;
        pi.write();

        int pres = vkQueuePresentKHR.invokeInt(new Object[]{ presentQueue, pi.getPointer() });
        if (pres == VK_ERROR_OUT_OF_DATE_KHR || pres == VK_SUBOPTIMAL_KHR) {
            recreateSwapchain(hwnd, vertSpv, fragSpv);
        } else {
            vkCheck(pres, "vkQueuePresentKHR");
        }

        frameIndex++;
    }

    // ------------------------------------------------------------
    // Final cleanup
    // ------------------------------------------------------------
    static void destroyDeviceSurfaceInstance() {
        Function vkDestroyDevice = vkGlobal("vkDestroyDevice");
        Function vkDestroySurfaceKHR = vkInst(instance, "vkDestroySurfaceKHR");
        Function vkDestroyInstance = vkGlobal("vkDestroyInstance");

        if (device != null && Pointer.nativeValue(device) != 0) {
            vkDestroyDevice.invokeVoid(new Object[]{ device, Pointer.NULL });
            device = null;
        }
        if (surface != 0) {
            vkDestroySurfaceKHR.invokeVoid(new Object[]{ instance, surface, Pointer.NULL });
            surface = 0;
        }
        if (instance != null && Pointer.nativeValue(instance) != 0) {
            vkDestroyInstance.invokeVoid(new Object[]{ instance, Pointer.NULL });
            instance = null;
        }
    }

}

if(typeof Module==="undefined"){var Module={};}
var Module=Module;var ENVIRONMENT_IS_NODE=typeof process==="object";if(ENVIRONMENT_IS_NODE){var fs=require("fs");Module["wasm"]=fs.readFileSync(__dirname+"/index.wasm")}function ready(){run()}var UTF8Decoder=typeof TextDecoder!=="undefined"?new TextDecoder("utf8"):undefined;function UTF8ArrayToString(heap,idx,maxBytesToRead){var endIdx=idx+maxBytesToRead;var endPtr=idx;while(heap[endPtr]&&!(endPtr>=endIdx))++endPtr;if(endPtr-idx>16&&heap.subarray&&UTF8Decoder){return UTF8Decoder.decode(heap.subarray(idx,endPtr))}else{var str="";while(idx<endPtr){var u0=heap[idx++];if(!(u0&128)){str+=String.fromCharCode(u0);continue}var u1=heap[idx++]&63;if((u0&224)==192){str+=String.fromCharCode((u0&31)<<6|u1);continue}var u2=heap[idx++]&63;if((u0&240)==224){u0=(u0&15)<<12|u1<<6|u2}else{u0=(u0&7)<<18|u1<<12|u2<<6|heap[idx++]&63}if(u0<65536){str+=String.fromCharCode(u0)}else{var ch=u0-65536;str+=String.fromCharCode(55296|ch>>10,56320|ch&1023)}}}return str}function UTF8ToString(ptr,maxBytesToRead){return ptr?UTF8ArrayToString(HEAPU8,ptr,maxBytesToRead):""}var HEAP8,HEAP16,HEAP32,HEAPU8,HEAPU16,HEAPU32,HEAPF32,HEAPF64;var wasmMemory,buffer,wasmTable;function updateGlobalBufferAndViews(b){buffer=b;HEAP8=new Int8Array(b);HEAP16=new Int16Array(b);HEAP32=new Int32Array(b);HEAPU8=new Uint8Array(b);HEAPU16=new Uint16Array(b);HEAPU32=new Uint32Array(b);HEAPF32=new Float32Array(b);HEAPF64=new Float64Array(b)}function glue_preint(){var entry=__glue_main_;if(entry){if(navigator["gpu"]){navigator["gpu"]["requestAdapter"]().then(function(adapter){adapter["requestDevice"]().then(function(device){Module["preinitializedWebGPUDevice"]=device;entry()})},function(){console.error("No WebGPU adapter; not starting")})}else{console.error("No support for WebGPU; not starting")}}else{console.error("Entry point not found; unable to start")}}var wasmTableMirror=[];function getWasmTableEntry(funcPtr){var func=wasmTableMirror[funcPtr];if(!func){if(funcPtr>=wasmTableMirror.length)wasmTableMirror.length=funcPtr+1;wasmTableMirror[funcPtr]=func=wasmTable.get(funcPtr)}return func}function _emscripten_request_animation_frame_loop(cb,userData){function tick(timeStamp){if(getWasmTableEntry(cb)(timeStamp,userData)){requestAnimationFrame(tick)}}return requestAnimationFrame(tick)}var WebGPU={initManagers:function(){if(WebGPU.mgrDevice)return;function makeManager(){return{objects:{},nextId:1,create:function(object,wrapper){wrapper=wrapper||{};var id=this.nextId++;wrapper.refcount=1;wrapper.object=object;this.objects[id]=wrapper;return id},get:function(id){if(!id)return undefined;var o=this.objects[id];return o.object},reference:function(id){var o=this.objects[id];o.refcount++},release:function(id){var o=this.objects[id];o.refcount--;if(o.refcount<=0){delete this.objects[id]}}}}WebGPU.mgrSurface=WebGPU.mgrSurface||makeManager();WebGPU.mgrSwapChain=WebGPU.mgrSwapChain||makeManager();WebGPU.mgrAdapter=WebGPU.mgrAdapter||makeManager();WebGPU.mgrDevice=WebGPU.mgrDevice||makeManager();WebGPU.mgrQueue=WebGPU.mgrQueue||makeManager();WebGPU.mgrCommandBuffer=WebGPU.mgrCommandBuffer||makeManager();WebGPU.mgrCommandEncoder=WebGPU.mgrCommandEncoder||makeManager();WebGPU.mgrRenderPassEncoder=WebGPU.mgrRenderPassEncoder||makeManager();WebGPU.mgrComputePassEncoder=WebGPU.mgrComputePassEncoder||makeManager();WebGPU.mgrBindGroup=WebGPU.mgrBindGroup||makeManager();WebGPU.mgrBuffer=WebGPU.mgrBuffer||makeManager();WebGPU.mgrSampler=WebGPU.mgrSampler||makeManager();WebGPU.mgrTexture=WebGPU.mgrTexture||makeManager();WebGPU.mgrTextureView=WebGPU.mgrTextureView||makeManager();WebGPU.mgrQuerySet=WebGPU.mgrQuerySet||makeManager();WebGPU.mgrBindGroupLayout=WebGPU.mgrBindGroupLayout||makeManager();WebGPU.mgrPipelineLayout=WebGPU.mgrPipelineLayout||makeManager();WebGPU.mgrRenderPipeline=WebGPU.mgrRenderPipeline||makeManager();WebGPU.mgrComputePipeline=WebGPU.mgrComputePipeline||makeManager();WebGPU.mgrShaderModule=WebGPU.mgrShaderModule||makeManager();WebGPU.mgrRenderBundleEncoder=WebGPU.mgrRenderBundleEncoder||makeManager();WebGPU.mgrRenderBundle=WebGPU.mgrRenderBundle||makeManager()},makeColor:function(ptr){return{"r":Number(HEAPF64[ptr>>3]),"g":Number(HEAPF64[ptr+8>>3]),"b":Number(HEAPF64[ptr+16>>3]),"a":Number(HEAPF64[ptr+24>>3])}},makeExtent3D:function(ptr){return{"width":HEAPU32[ptr>>2],"height":HEAPU32[ptr+4>>2],"depthOrArrayLayers":HEAPU32[ptr+8>>2]}},makeOrigin3D:function(ptr){return{"x":HEAPU32[ptr>>2],"y":HEAPU32[ptr+4>>2],"z":HEAPU32[ptr+8>>2]}},makeImageCopyTexture:function(ptr){return{"texture":WebGPU.mgrTexture.get(HEAP32[ptr+4>>2]),"mipLevel":HEAPU32[ptr+8>>2],"origin":WebGPU.makeOrigin3D(ptr+12),"aspect":WebGPU.TextureAspect[HEAPU32[ptr+24>>2]]}},makeTextureDataLayout:function(ptr){var bytesPerRow=HEAPU32[ptr+16>>2];var rowsPerImage=HEAPU32[ptr+20>>2];return{"offset":HEAPU32[ptr+4+8>>2]*4294967296+HEAPU32[ptr+8>>2],"bytesPerRow":bytesPerRow===4294967295?undefined:bytesPerRow,"rowsPerImage":rowsPerImage===4294967295?undefined:rowsPerImage}},makeImageCopyBuffer:function(ptr){var layoutPtr=ptr+8;var bufferCopyView=WebGPU.makeTextureDataLayout(layoutPtr);bufferCopyView["buffer"]=WebGPU.mgrBuffer.get(HEAP32[ptr+32>>2]);return bufferCopyView},makePipelineConstants:function(constantCount,constantsPtr){if(!constantCount)return;var constants={};for(var i=0;i<constantCount;++i){var entryPtr=constantsPtr+16*i;var key=UTF8ToString(HEAP32[entryPtr+4>>2]);constants[key]=Number(HEAPF64[entryPtr+8>>3])}return constants},makeProgrammableStageDescriptor:function(ptr){if(!ptr)return undefined;return{"module":WebGPU.mgrShaderModule.get(HEAP32[ptr+4>>2]),"entryPoint":UTF8ToString(HEAP32[ptr+8>>2]),"constants":WebGPU.makePipelineConstants(HEAPU32[ptr+12>>2],HEAP32[ptr+16>>2])}},DeviceLostReason:{undefined:0,destroyed:1},PreferredFormat:{rgba8unorm:18,bgra8unorm:23},AddressMode:["repeat","mirror-repeat","clamp-to-edge"],BlendFactor:["zero","one","src","one-minus-src","src-alpha","one-minus-src-alpha","dst","one-minus-dst","dst-alpha","one-minus-dst-alpha","src-alpha-saturated","constant","one-minus-constant"],BlendOperation:["add","subtract","reverse-subtract","min","max"],BufferBindingType:[,"uniform","storage","read-only-storage"],CompareFunction:[,"never","less","less-equal","greater","greater-equal","equal","not-equal","always"],CullMode:["none","front","back"],ErrorFilter:["validation","out-of-memory"],FeatureName:[,"depth-clamping","depth24unorm-stencil8","depth32float-stencil8","timestamp-query","pipeline-statistics-query","texture-compression-bc","texture-compression-etc2","texture-compression-astc"],FilterMode:["nearest","linear"],FrontFace:["ccw","cw"],IndexFormat:[,"uint16","uint32"],PipelineStatisticName:["vertex-shader-invocations","clipper-invocations","clipper-primitives-out","fragment-shader-invocations","compute-shader-invocations"],PowerPreference:["low-power","high-performance"],PrimitiveTopology:["point-list","line-list","line-strip","triangle-list","triangle-strip"],QueryType:["occlusion","pipeline-statistics","timestamp"],SamplerBindingType:[,"filtering","non-filtering","comparison"],StencilOperation:["keep","zero","replace","invert","increment-clamp","decrement-clamp","increment-wrap","decrement-wrap"],StorageTextureAccess:[,"write-only"],StoreOp:["store","discard"],TextureAspect:["all","stencil-only","depth-only"],TextureComponentType:["float","sint","uint","depth-comparison"],TextureDimension:["1d","2d","3d"],TextureFormat:[,"r8unorm","r8snorm","r8uint","r8sint","r16uint","r16sint","r16float","rg8unorm","rg8snorm","rg8uint","rg8sint","r32float","r32uint","r32sint","rg16uint","rg16sint","rg16float","rgba8unorm","rgba8unorm-srgb","rgba8snorm","rgba8uint","rgba8sint","bgra8unorm","bgra8unorm-srgb","rgb10a2unorm","rg11b10ufloat","rgb9e5ufloat","rg32float","rg32uint","rg32sint","rgba16uint","rgba16sint","rgba16float","rgba32float","rgba32uint","rgba32sint","stencil8","depth16unorm","depth24plus","depth24plus-stencil8","depth32float","bc1-rgba-unorm","bc1-rgba-unorm-srgb","bc2-rgba-unorm","bc2-rgba-unorm-srgb","bc3-rgba-unorm","bc3-rgba-unorm-srgb","bc4-r-unorm","bc4-r-snorm","bc5-rg-unorm","bc5-rg-snorm","bc6h-rgb-ufloat","bc6h-rgb-float","bc7-rgba-unorm","bc7-rgba-unorm-srgb","etc2-rgb8unorm","etc2-rgb8unorm-srgb","etc2-rgb8a1unorm","etc2-rgb8a1unorm-srgb","etc2-rgba8unorm","etc2-rgba8unorm-srgb","eac-r11unorm","eac-r11snorm","eac-rg11unorm","eac-rg11snorm","astc-4x4-unorm","astc-4x4-unorm-srgb","astc-5x4-unorm","astc-5x4-unorm-srgb","astc-5x5-unorm","astc-5x5-unorm-srgb","astc-6x5-unorm","astc-6x5-unorm-srgb","astc-6x6-unorm","astc-6x6-unorm-srgb","astc-8x5-unorm","astc-8x5-unorm-srgb","astc-8x6-unorm","astc-8x6-unorm-srgb","astc-8x8-unorm","astc-8x8-unorm-srgb","astc-10x5-unorm","astc-10x5-unorm-srgb","astc-10x6-unorm","astc-10x6-unorm-srgb","astc-10x8-unorm","astc-10x8-unorm-srgb","astc-10x10-unorm","astc-10x10-unorm-srgb","astc-12x10-unorm","astc-12x10-unorm-srgb","astc-12x12-unorm","astc-12x12-unorm-srgb"],TextureSampleType:[,"float","unfilterable-float","depth","sint","uint"],TextureViewDimension:[,"1d","2d","2d-array","cube","cube-array","3d"],VertexFormat:[,"uint8x2","uint8x4","sint8x2","sint8x4","unorm8x2","unorm8x4","snorm8x2","snorm8x4","uint16x2","uint16x4","sint16x2","sint16x4","unorm16x2","unorm16x4","snorm16x2","snorm16x4","float16x2","float16x4","float32","float32x2","float32x3","float32x4","uint32","uint32x2","uint32x3","uint32x4","sint32","sint32x2","sint32x3","sint32x4"],VertexStepMode:["vertex","instance"]};function _emscripten_webgpu_get_device(){var device=Module["preinitializedWebGPUDevice"];var deviceWrapper={queueId:WebGPU.mgrQueue.create(device["queue"])};return WebGPU.mgrDevice.create(device,deviceWrapper)}function _wgpuCommandBufferRelease(id){WebGPU.mgrCommandBuffer.release(id)}function _wgpuCommandEncoderBeginRenderPass(encoderId,descriptor){function makeColorAttachment(caPtr){var loadOpInt=HEAPU32[caPtr+8>>2];var loadValue=loadOpInt?"load":WebGPU.makeColor(caPtr+16);return{"view":WebGPU.mgrTextureView.get(HEAPU32[caPtr>>2]),"resolveTarget":WebGPU.mgrTextureView.get(HEAPU32[caPtr+4>>2]),"storeOp":WebGPU.StoreOp[HEAPU32[caPtr+12>>2]],"loadValue":loadValue}}function makeColorAttachments(count,caPtr){var attachments=[];for(var i=0;i<count;++i){attachments.push(makeColorAttachment(caPtr+48*i))}return attachments}function makeDepthStencilAttachment(dsaPtr){if(dsaPtr===0)return undefined;var depthLoadOpInt=HEAPU32[dsaPtr+4>>2];var depthLoadValue=depthLoadOpInt?"load":HEAPF32[dsaPtr+12>>2];var stencilLoadOpInt=HEAPU32[dsaPtr+20>>2];var stencilLoadValue=stencilLoadOpInt?"load":HEAPU32[dsaPtr+28>>2];return{"view":WebGPU.mgrTextureView.get(HEAPU32[dsaPtr>>2]),"depthStoreOp":WebGPU.StoreOp[HEAPU32[dsaPtr+8>>2]],"depthLoadValue":depthLoadValue,"depthReadOnly":HEAP8[dsaPtr+16>>0]!==0,"stencilStoreOp":WebGPU.StoreOp[HEAPU32[dsaPtr+24>>2]],"stencilLoadValue":stencilLoadValue,"stencilReadOnly":HEAP8[dsaPtr+32>>0]!==0}}function makeRenderPassDescriptor(descriptor){var desc={"label":undefined,"colorAttachments":makeColorAttachments(HEAPU32[descriptor+8>>2],HEAP32[descriptor+12>>2]),"depthStencilAttachment":makeDepthStencilAttachment(HEAP32[descriptor+16>>2]),"occlusionQuerySet":WebGPU.mgrQuerySet.get(HEAP32[descriptor+20>>2])};var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)desc["label"]=UTF8ToString(labelPtr);return desc}var desc=makeRenderPassDescriptor(descriptor);var commandEncoder=WebGPU.mgrCommandEncoder.get(encoderId);return WebGPU.mgrRenderPassEncoder.create(commandEncoder["beginRenderPass"](desc))}function _wgpuCommandEncoderFinish(encoderId){var commandEncoder=WebGPU.mgrCommandEncoder.get(encoderId);return WebGPU.mgrCommandBuffer.create(commandEncoder["finish"]())}function _wgpuCommandEncoderRelease(id){WebGPU.mgrCommandEncoder.release(id)}function _wgpuDeviceCreateBuffer(deviceId,descriptor){var mappedAtCreation=HEAP8[descriptor+24>>0]!==0;var desc={"label":undefined,"usage":HEAPU32[descriptor+8>>2],"size":HEAPU32[descriptor+4+16>>2]*4294967296+HEAPU32[descriptor+16>>2],"mappedAtCreation":mappedAtCreation};var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)desc["label"]=UTF8ToString(labelPtr);var device=WebGPU.mgrDevice.get(deviceId);var bufferWrapper={};var id=WebGPU.mgrBuffer.create(device["createBuffer"](desc),bufferWrapper);if(mappedAtCreation){bufferWrapper.mapMode=2;bufferWrapper.onUnmap=[]}return id}function _wgpuDeviceCreateCommandEncoder(deviceId,descriptor){var desc;if(descriptor){desc={"label":undefined};var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)desc["label"]=UTF8ToString(labelPtr)}var device=WebGPU.mgrDevice.get(deviceId);return WebGPU.mgrCommandEncoder.create(device["createCommandEncoder"](desc))}function _wgpuDeviceCreatePipelineLayout(deviceId,descriptor){var bglCount=HEAPU32[descriptor+8>>2];var bglPtr=HEAP32[descriptor+12>>2];var bgls=[];for(var i=0;i<bglCount;++i){bgls.push(WebGPU.mgrBindGroupLayout.get(HEAP32[bglPtr+4*i>>2]))}var desc={"label":undefined,"bindGroupLayouts":bgls};var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)desc["label"]=UTF8ToString(labelPtr);var device=WebGPU.mgrDevice.get(deviceId);return WebGPU.mgrPipelineLayout.create(device["createPipelineLayout"](desc))}function _wgpuDeviceCreateRenderPipeline(deviceId,descriptor){function makePrimitiveState(rsPtr){if(!rsPtr)return undefined;return{"topology":WebGPU.PrimitiveTopology[HEAPU32[rsPtr+4>>2]],"stripIndexFormat":WebGPU.IndexFormat[HEAPU32[rsPtr+8>>2]],"frontFace":WebGPU.FrontFace[HEAPU32[rsPtr+12>>2]],"cullMode":WebGPU.CullMode[HEAPU32[rsPtr+16>>2]]}}function makeBlendComponent(bdPtr){if(!bdPtr)return undefined;return{"operation":WebGPU.BlendOperation[HEAPU32[bdPtr>>2]],"srcFactor":WebGPU.BlendFactor[HEAPU32[bdPtr+4>>2]],"dstFactor":WebGPU.BlendFactor[HEAPU32[bdPtr+8>>2]]}}function makeBlendState(bsPtr){if(!bsPtr)return undefined;return{"alpha":makeBlendComponent(bsPtr+12),"color":makeBlendComponent(bsPtr+0)}}function makeColorState(csPtr){return{"format":WebGPU.TextureFormat[HEAPU32[csPtr+4>>2]],"blend":makeBlendState(HEAP32[csPtr+8>>2]),"writeMask":HEAPU32[csPtr+12>>2]}}function makeColorStates(count,csArrayPtr){var states=[];for(var i=0;i<count;++i){states.push(makeColorState(csArrayPtr+16*i))}return states}function makeStencilStateFace(ssfPtr){return{"compare":WebGPU.CompareFunction[HEAPU32[ssfPtr>>2]],"failOp":WebGPU.StencilOperation[HEAPU32[ssfPtr+4>>2]],"depthFailOp":WebGPU.StencilOperation[HEAPU32[ssfPtr+8>>2]],"passOp":WebGPU.StencilOperation[HEAPU32[ssfPtr+12>>2]]}}function makeDepthStencilState(dssPtr){if(!dssPtr)return undefined;return{"format":WebGPU.TextureFormat[HEAPU32[dssPtr+4>>2]],"depthWriteEnabled":HEAP8[dssPtr+8>>0]!==0,"depthCompare":WebGPU.CompareFunction[HEAPU32[dssPtr+12>>2]],"stencilFront":makeStencilStateFace(dssPtr+16),"stencilBack":makeStencilStateFace(dssPtr+32),"stencilReadMask":HEAPU32[dssPtr+48>>2],"stencilWriteMask":HEAPU32[dssPtr+52>>2],"depthBias":HEAP32[dssPtr+56>>2],"depthBiasSlopeScale":HEAPF32[dssPtr+60>>2],"depthBiasClamp":HEAPF32[dssPtr+64>>2]}}function makeVertexAttribute(vaPtr){return{"format":WebGPU.VertexFormat[HEAPU32[vaPtr>>2]],"offset":HEAPU32[vaPtr+4+8>>2]*4294967296+HEAPU32[vaPtr+8>>2],"shaderLocation":HEAPU32[vaPtr+16>>2]}}function makeVertexAttributes(count,vaArrayPtr){var vas=[];for(var i=0;i<count;++i){vas.push(makeVertexAttribute(vaArrayPtr+i*24))}return vas}function makeVertexBuffer(vbPtr){if(!vbPtr)return undefined;return{"arrayStride":HEAPU32[vbPtr+4>>2]*4294967296+HEAPU32[vbPtr>>2],"stepMode":WebGPU.VertexStepMode[HEAPU32[vbPtr+8>>2]],"attributes":makeVertexAttributes(HEAPU32[vbPtr+12>>2],HEAP32[vbPtr+16>>2])}}function makeVertexBuffers(count,vbArrayPtr){if(!count)return undefined;var vbs=[];for(var i=0;i<count;++i){vbs.push(makeVertexBuffer(vbArrayPtr+i*24))}return vbs}function makeVertexState(viPtr){if(!viPtr)return undefined;return{"module":WebGPU.mgrShaderModule.get(HEAP32[viPtr+4>>2]),"entryPoint":UTF8ToString(HEAP32[viPtr+8>>2]),"constants":WebGPU.makePipelineConstants(HEAPU32[viPtr+12>>2],HEAP32[viPtr+16>>2]),"buffers":makeVertexBuffers(HEAPU32[viPtr+20>>2],HEAP32[viPtr+24>>2])}}function makeMultisampleState(msPtr){if(!msPtr)return undefined;return{"count":HEAPU32[msPtr+4>>2],"mask":HEAPU32[msPtr+8>>2],"alphaToCoverageEnabled":HEAP8[msPtr+12>>0]!==0}}function makeFragmentState(fsPtr){if(!fsPtr)return undefined;return{"module":WebGPU.mgrShaderModule.get(HEAP32[fsPtr+4>>2]),"entryPoint":UTF8ToString(HEAP32[fsPtr+8>>2]),"constants":WebGPU.makePipelineConstants(HEAPU32[fsPtr+12>>2],HEAP32[fsPtr+16>>2]),"targets":makeColorStates(HEAPU32[fsPtr+20>>2],HEAP32[fsPtr+24>>2])}}var desc={"label":undefined,"layout":WebGPU.mgrPipelineLayout.get(HEAP32[descriptor+8>>2]),"vertex":makeVertexState(descriptor+12),"primitive":makePrimitiveState(descriptor+40),"depthStencil":makeDepthStencilState(HEAP32[descriptor+60>>2]),"multisample":makeMultisampleState(descriptor+64),"fragment":makeFragmentState(HEAP32[descriptor+80>>2])};var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)desc["label"]=UTF8ToString(labelPtr);var device=WebGPU.mgrDevice.get(deviceId);return WebGPU.mgrRenderPipeline.create(device["createRenderPipeline"](desc))}function _wgpuDeviceCreateShaderModule(deviceId,descriptor){var nextInChainPtr=HEAP32[descriptor>>2];var sType=HEAPU32[nextInChainPtr+4>>2];var desc={"label":undefined,"code":""};var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)desc["label"]=UTF8ToString(labelPtr);switch(sType){case 5:{var count=HEAPU32[nextInChainPtr+8>>2];var start=HEAP32[nextInChainPtr+12>>2];desc["code"]=HEAPU32.subarray(start>>2,(start>>2)+count);break}case 6:{var sourcePtr=HEAP32[nextInChainPtr+8>>2];if(sourcePtr){desc["code"]=UTF8ToString(sourcePtr)}break}}var device=WebGPU.mgrDevice.get(deviceId);return WebGPU.mgrShaderModule.create(device["createShaderModule"](desc))}function _wgpuDeviceCreateSwapChain(deviceId,surfaceId,descriptor){var device=WebGPU.mgrDevice.get(deviceId);var context=WebGPU.mgrSurface.get(surfaceId);var configuration={"device":device,"format":WebGPU.TextureFormat[HEAPU32[descriptor+12>>2]],"usage":HEAPU32[descriptor+8>>2],"size":[HEAPU32[descriptor+16>>2],HEAPU32[descriptor+20>>2]]};context["configure"](configuration);return WebGPU.mgrSwapChain.create(context)}function _wgpuDeviceGetQueue(deviceId){var queueId=WebGPU.mgrDevice.objects[deviceId].queueId;WebGPU.mgrQueue.reference(queueId);return queueId}function maybeCStringToJsString(cString){return cString>2?UTF8ToString(cString):cString}var specialHTMLTargets=[0,typeof document!=="undefined"?document:0,typeof window!=="undefined"?window:0];function findEventTarget(target){target=maybeCStringToJsString(target);var domElement=specialHTMLTargets[target]||(typeof document!=="undefined"?document.querySelector(target):undefined);return domElement}function findCanvasEventTarget(target){return findEventTarget(target)}function _wgpuInstanceCreateSurface(instanceId,descriptor){var nextInChainPtr=HEAP32[descriptor>>2];var descriptorFromCanvasHTMLSelector=nextInChainPtr;var selectorPtr=HEAP32[descriptorFromCanvasHTMLSelector+8>>2];var canvas=findCanvasEventTarget(selectorPtr);const context=canvas.getContext("webgpu");if(!context)return 0;var labelPtr=HEAP32[descriptor+4>>2];if(labelPtr)context.surfaceLabelWebGPU=UTF8ToString(labelPtr);return WebGPU.mgrSurface.create(context)}function _wgpuPipelineLayoutRelease(id){WebGPU.mgrPipelineLayout.release(id)}function _wgpuQueueSubmit(queueId,commandCount,commands){var queue=WebGPU.mgrQueue.get(queueId);var cmds=Array.from(HEAP32.subarray(commands>>2,(commands>>2)+commandCount),function(id){return WebGPU.mgrCommandBuffer.get(id)});queue["submit"](cmds)}function _wgpuQueueWriteBuffer(queueId,bufferId,bufferOffset_low,bufferOffset_high,data,size){var queue=WebGPU.mgrQueue.get(queueId);var buffer=WebGPU.mgrBuffer.get(bufferId);var bufferOffset=bufferOffset_high*4294967296+bufferOffset_low;queue["writeBuffer"](buffer,bufferOffset,HEAPU8,data,size)}function _wgpuRenderPassEncoderDrawIndexed(passId,indexCount,instanceCount,firstIndex,baseVertex,firstInstance){var pass=WebGPU.mgrRenderPassEncoder.get(passId);pass["drawIndexed"](indexCount,instanceCount,firstIndex,baseVertex,firstInstance)}function _wgpuRenderPassEncoderEndPass(passId){var pass=WebGPU.mgrRenderPassEncoder.get(passId);pass["endPass"]()}function _wgpuRenderPassEncoderRelease(id){WebGPU.mgrRenderPassEncoder.release(id)}function _wgpuRenderPassEncoderSetIndexBuffer(passId,bufferId,format,offset_low,offset_high,size_low,size_high){var pass=WebGPU.mgrRenderPassEncoder.get(passId);var buffer=WebGPU.mgrBuffer.get(bufferId);var offset=offset_high*4294967296+offset_low;var size=size_high===-1&&size_low===-1?undefined:size_high*4294967296+size_low;pass["setIndexBuffer"](buffer,WebGPU.IndexFormat[format],offset,size)}function _wgpuRenderPassEncoderSetPipeline(passId,pipelineId){var pass=WebGPU.mgrRenderPassEncoder.get(passId);var pipeline=WebGPU.mgrRenderPipeline.get(pipelineId);pass["setPipeline"](pipeline)}function _wgpuRenderPassEncoderSetVertexBuffer(passId,slot,bufferId,offset_low,offset_high,size_low,size_high){var pass=WebGPU.mgrRenderPassEncoder.get(passId);var buffer=WebGPU.mgrBuffer.get(bufferId);var offset=offset_high*4294967296+offset_low;var size=size_high===-1&&size_low===-1?undefined:size_high*4294967296+size_low;pass["setVertexBuffer"](slot,buffer,offset,size)}function _wgpuShaderModuleRelease(id){WebGPU.mgrShaderModule.release(id)}function _wgpuSwapChainGetCurrentTextureView(swapChainId){var context=WebGPU.mgrSwapChain.get(swapChainId);return WebGPU.mgrTextureView.create(context["getCurrentTexture"]()["createView"]())}function _wgpuTextureViewRelease(id){WebGPU.mgrTextureView.release(id)}WebGPU.initManagers();var asmLibraryArg={"z":_emscripten_request_animation_frame_loop,"p":_emscripten_webgpu_get_device,"A":glue_preint,"n":_wgpuCommandBufferRelease,"w":_wgpuCommandEncoderBeginRenderPass,"r":_wgpuCommandEncoderFinish,"q":_wgpuCommandEncoderRelease,"a":_wgpuDeviceCreateBuffer,"x":_wgpuDeviceCreateCommandEncoder,"f":_wgpuDeviceCreatePipelineLayout,"e":_wgpuDeviceCreateRenderPipeline,"b":_wgpuDeviceCreateShaderModule,"g":_wgpuDeviceCreateSwapChain,"l":_wgpuDeviceGetQueue,"h":_wgpuInstanceCreateSurface,"d":_wgpuPipelineLayoutRelease,"o":_wgpuQueueSubmit,"k":_wgpuQueueWriteBuffer,"u":_wgpuRenderPassEncoderDrawIndexed,"t":_wgpuRenderPassEncoderEndPass,"s":_wgpuRenderPassEncoderRelease,"i":_wgpuRenderPassEncoderSetIndexBuffer,"v":_wgpuRenderPassEncoderSetPipeline,"j":_wgpuRenderPassEncoderSetVertexBuffer,"c":_wgpuShaderModuleRelease,"y":_wgpuSwapChainGetCurrentTextureView,"m":_wgpuTextureViewRelease};function run(){var ret=_main()}function initRuntime(asm){asm["C"]()}var imports={"a":asmLibraryArg};var __glue_main_,_main,_malloc,_free;WebAssembly.instantiate(Module["wasm"],imports).then(function(output){var asm=output.instance.exports;__glue_main_=asm["D"];_main=asm["E"];_malloc=asm["malloc"];_free=asm["free"];wasmTable=asm["F"];wasmMemory=asm["B"];updateGlobalBufferAndViews(wasmMemory.buffer);initRuntime(asm);ready()});

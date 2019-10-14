// This is an open source non-commercial project. Dear PVS-Studio, please check it.
// PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com
// ******************************************************************
// *
// *  This file is part of the Cxbx project.
// *
// *  Cxbx and Cxbe are free software; you can redistribute them
// *  and/or modify them under the terms of the GNU General Public
// *  License as published by the Free Software Foundation; either
// *  version 2 of the license, or (at your option) any later version.
// *
// *  This program is distributed in the hope that it will be useful,
// *  but WITHOUT ANY WARRANTY; without even the implied warranty of
// *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// *  GNU General Public License for more details.
// *
// *  You should have recieved a copy of the GNU General Public License
// *  along with this program; see the file COPYING.
// *  If not, write to the Free Software Foundation, Inc.,
// *  59 Temple Place - Suite 330, Bostom, MA 02111-1307, USA.
// *
// *  (c) 2019 Luke Usher
// *
// *  All rights reserved
// *
// ******************************************************************
#define LOG_PREFIX CXBXR_MODULE::D3DST


#include "RenderStates.h"
#include "Logging.h"
#include "core/hle/D3D8/Direct3D9/Direct3D9.h" // For g_pD3DDevice
#include "core/hle/D3D8/XbConvert.h"

bool XboxRenderStateConverter::Init()
{
    if (g_SymbolAddresses.find("D3DDeferredRenderState") != g_SymbolAddresses.end()) {
        D3D__RenderState = (uint32_t*)g_SymbolAddresses["D3DDeferredRenderState"];
    } else {
        return false;
    }

    // At this point, D3D__RenderState points to the first Deferred render state
    // Do a little magic to verify that it's correct, then count back to determine the
    // start offset of the entire structure
    VerifyAndFixDeferredRenderStateOffset();

    // Now use the verified Deferred offset to derive the D3D__RenderState offset
    DeriveRenderStateOffsetFromDeferredRenderStateOffset();

    // Build a mapping of Cxbx Render State indexes to indexes within the current XDK
    BuildRenderStateMappingTable();

    // Set Initial Values
    StoreInitialValues();

    return true;
}

void XboxRenderStateConverter::VerifyAndFixDeferredRenderStateOffset()
{
    DWORD CullModeOffset = g_SymbolAddresses["D3DRS_CULLMODE"];
    // If we found a valid CullMode offset, verify the symbol location
    if (CullModeOffset == 0) {
        EmuLog(LOG_LEVEL::WARNING, "D3DRS_CULLMODE could not be found. Please update the XbSymbolDatabase submodule");
        return;
    }

    // Calculate index of D3DRS_CULLMODE for this XDK. We start counting from the first deferred state (D3DRS_FOGENABLE)
    DWORD CullModeIndex = 0;
    for (int i = XTL::X_D3DRS_FOGENABLE; i < XTL::X_D3DRS_CULLMODE; i++) {
        if (DxbxRenderStateInfo[i].V <= g_LibVersion_D3D8) {
            CullModeIndex++;
        }
    }

    // If the offset was incorrect, calculate the correct offset, log it, and fix it
    if ((DWORD)(&D3D__RenderState[CullModeIndex]) != CullModeOffset) {
        DWORD CorrectOffset = CullModeOffset - (CullModeIndex * sizeof(DWORD));
        EmuLog(LOG_LEVEL::WARNING, "EmuD3DDeferredRenderState returned by XboxSymbolDatabase (0x%08X) was incorrect. Correcting to be 0x%08X.\nPlease file an issue with the XbSymbolDatabase project", D3D__RenderState, CorrectOffset);
        D3D__RenderState = (uint32_t*)CorrectOffset;
    }
}

void XboxRenderStateConverter::DeriveRenderStateOffsetFromDeferredRenderStateOffset()
{
    // When this function is called. D3D__RenderState actually points to the first deferred render state
    // this is D3DRS_FOGENABLE. We can count back from this using our RenderStateInfo table to find
    // the start of D3D__RenderStates.

    // Count the number of render states (for this XDK) between 0 and D3DRS_FOGENABLE
    int FogEnableOffset = 0;
    for (unsigned int RenderState = XTL::X_D3DRS_PSALPHAINPUTS0; RenderState < XTL::X_D3DRS_FOGENABLE; RenderState++) {
        // if the current renderstate exists in this XDK version, count it
        if (DxbxRenderStateInfo[RenderState].V <= g_LibVersion_D3D8) {
            FogEnableOffset++;
        }
    }

    // At this point, FogEnableOffset should point to the index of D3DRS_FOGENABLE for the given XDK
    // This will be correct as long as our table DxbxRenderStateInfo is correct
    // We can get the correct 0 offset by using a negative index
    D3D__RenderState = &D3D__RenderState[-FogEnableOffset];
}

void XboxRenderStateConverter::BuildRenderStateMappingTable()
{
    EmuLog(LOG_LEVEL::INFO, "Building Cxbx to XDK Render State Mapping Table");

    XboxRenderStateOffsets.fill(-1);

    int XboxIndex = 0;
    for (unsigned int RenderState = XTL::X_D3DRS_PSALPHAINPUTS0; RenderState <= XTL::X_D3DRS_LAST; RenderState++) {
        if (DxbxRenderStateInfo[RenderState].V <= g_LibVersion_D3D8) {
            XboxRenderStateOffsets[RenderState] = XboxIndex;
            EmuLog(LOG_LEVEL::INFO, "%s = %d", DxbxRenderStateInfo[RenderState].S, XboxIndex);
            XboxIndex++;
            continue;
        }

        EmuLog(LOG_LEVEL::INFO, "%s Not Present", DxbxRenderStateInfo[RenderState].S);
    }
}

void XboxRenderStateConverter::SetDirty()
{
    PreviousRenderStateValues.fill(-1);
}

void* XboxRenderStateConverter::GetPixelShaderRenderStatePointer()
{
    return &D3D__RenderState[XTL::X_D3DRS_PS_FIRST];
}

bool XboxRenderStateConverter::XboxRenderStateExists(uint32_t State)
{
    if (XboxRenderStateOffsets[State] >= 0) {
        return true;
    }

    return false;
}

bool XboxRenderStateConverter::XboxRenderStateValueChanged(uint32_t State)
{
    if (XboxRenderStateExists(State) && GetXboxRenderState(State) != PreviousRenderStateValues[State]) {
        return true;
    }

    return false;
}

void XboxRenderStateConverter::SetXboxRenderState(uint32_t State, uint32_t Value)
{
    if (!XboxRenderStateExists(State)) {
        EmuLog(LOG_LEVEL::WARNING, "Attempt to write a Renderstate (%s) that does not exist in the current D3D8 XDK Version (%d)", DxbxRenderStateInfo[State].S, g_LibVersion_D3D8);
        return;
    }

    D3D__RenderState[XboxRenderStateOffsets[State]] = Value;
}

uint32_t XboxRenderStateConverter::GetXboxRenderState(uint32_t State)
{
    if (!XboxRenderStateExists(State)) {
        EmuLog(LOG_LEVEL::WARNING, "Attempt to read a Renderstate (%s) that does not exist in the current D3D8 XDK Version (%d)", DxbxRenderStateInfo[State].S, g_LibVersion_D3D8);
        return 0;
    }

    return D3D__RenderState[XboxRenderStateOffsets[State]];
}

void XboxRenderStateConverter::StoreInitialValues()
{
    for (unsigned int RenderState = XTL::X_D3DRS_PSALPHAINPUTS0; RenderState <= XTL::X_D3DRS_LAST; RenderState++) {
        // Skip Render States that don't exist within this XDK
        if (!XboxRenderStateExists(RenderState)) {
            continue;
        }

        PreviousRenderStateValues[RenderState] = GetXboxRenderState(RenderState);
    }
}

void XboxRenderStateConverter::SetWireFrameMode(int wireframe)
{
    WireFrameMode = wireframe;

    // Wireframe mode changed, so we must force the Fill Mode renderstate to dirty
    // At next call to Apply, the desired WireFrame mode will be set
    PreviousRenderStateValues[XTL::X_D3DRS_FILLMODE] = -1;
}

void XboxRenderStateConverter::Apply()
{
    // Iterate through each RenderState and set the associated host render state
    // We start counting at X_D3DRS_SIMPLE_FIRST, to skip the pixel shader renderstates handled elsewhere
    for (unsigned int RenderState = XTL::X_D3DRS_SIMPLE_FIRST; RenderState <= XTL::X_D3DRS_LAST; RenderState++) {
        // Skip any renderstate that does not exist in the current XDK, or have not changed since the previous update call
        // Also skip PSTextureModes, which is a special case used by Pixel Shaders
        if (!XboxRenderStateExists(RenderState) || !XboxRenderStateValueChanged(RenderState) || RenderState == XTL::X_D3DRS_PSTEXTUREMODES) {
            continue;
        }

        auto Value = GetXboxRenderState(RenderState);
        EmuLog(LOG_LEVEL::DEBUG, "XboxRenderStateConverter::Apply(%s, %X)\n", DxbxRenderStateInfo[RenderState].S, Value);

        if (RenderState <= XTL::X_D3DRS_SIMPLE_LAST) {
            ApplySimpleRenderState(RenderState, Value);
        } else if (RenderState <= XTL::X_D3DRS_DEFERRED_LAST) {
            ApplyDeferredRenderState(RenderState, Value);
        } else if (RenderState <= XTL::X_D3DRS_COMPLEX_LAST) {
            ApplyComplexRenderState(RenderState, Value);
        }

        PreviousRenderStateValues[RenderState] = Value;
    }
}

void XboxRenderStateConverter::ApplySimpleRenderState(uint32_t State, uint32_t Value)
{
    switch (State) {
        case XTL::X_D3DRS_COLORWRITEENABLE: {
            DWORD OrigValue = Value;
            Value = 0;

            if (OrigValue & (1L << 16)) {
                Value |= D3DCOLORWRITEENABLE_RED;
            }

            if (OrigValue & (1L << 8)) {
                Value |= D3DCOLORWRITEENABLE_GREEN;
            }

            if (OrigValue & (1L << 0)) {
                Value |= D3DCOLORWRITEENABLE_BLUE;
            }

            if (OrigValue & (1L << 24)) {
                Value |= D3DCOLORWRITEENABLE_ALPHA;
            }
        } break;
        case XTL::X_D3DRS_SHADEMODE:
            Value = EmuXB2PC_D3DSHADEMODE(Value);
            break;
        case XTL::X_D3DRS_BLENDOP:
            Value = EmuXB2PC_D3DBLENDOP(Value);
            break;
        case XTL::X_D3DRS_SRCBLEND:
        case XTL::X_D3DRS_DESTBLEND:
            Value = EmuXB2PC_D3DBLEND(Value);
            break;
        case XTL::X_D3DRS_ZFUNC:
        case XTL::X_D3DRS_ALPHAFUNC:
        case XTL::X_D3DRS_STENCILFUNC:
            Value = EmuXB2PC_D3DCMPFUNC(Value);
            break;
        case XTL::X_D3DRS_STENCILZFAIL:
        case XTL::X_D3DRS_STENCILPASS:
            Value = EmuXB2PC_D3DSTENCILOP(Value);
            break;
        case XTL::X_D3DRS_ALPHATESTENABLE:
            if (g_LibVersion_D3D8 == 3925) {
                // HACK: Many 3925 have missing polygons when this is true
                // Until  we find out the true underlying cause, and carry on
                // Test Cases: Halo, Silent Hill 2.
                LOG_TEST_CASE("Applying 3925 alpha test disable hack");
                Value = false;
            }
            break;
        case XTL::X_D3DRS_ALPHABLENDENABLE:
        case XTL::X_D3DRS_BLENDCOLOR:
        case XTL::X_D3DRS_ALPHAREF: case XTL::X_D3DRS_ZWRITEENABLE:
        case XTL::X_D3DRS_DITHERENABLE: case XTL::X_D3DRS_STENCILREF:
        case XTL::X_D3DRS_STENCILMASK: case XTL::X_D3DRS_STENCILWRITEMASK:
            // These render states require no conversion, so we simply
            // allow SetRenderState to be called with no changes
            break;
        default:
            // Only log missing state if it has a PC counterpart
            if (DxbxRenderStateInfo[State].PC != 0) {
                EmuLog(LOG_LEVEL::WARNING, "ApplySimpleRenderState(%s, 0x%.08X) is unimplemented!", DxbxRenderStateInfo[State].S, Value);
            }
            return;
    }

    // Skip RenderStates that don't have a defined PC counterpart
    if (DxbxRenderStateInfo[State].PC == 0) {
        return;
    }

    g_pD3DDevice->SetRenderState((D3DRENDERSTATETYPE)(DxbxRenderStateInfo[State].PC), Value);
}

void XboxRenderStateConverter::ApplyDeferredRenderState(uint32_t State, uint32_t Value)
{
    // Convert from Xbox Data Formats to PC
    switch (State) {
        case XTL::X_D3DRS_FOGSTART:
        case XTL::X_D3DRS_FOGEND: {
            // HACK: If the fog start/fog-end are negative, make them positive
            // This fixes Smashing Drive on non-nvidia hardware
            // Cause appears to be non-nvidia drivers clamping values < 0 to 0
            // Resulting in the fog formula becoming (0 - d) / 0, which breaks rendering
            // This prevents that scenario for screen-space fog, *hopefully* without breaking eye-based fog also
            float fogValue = *(float*)& Value;
            if (fogValue < 0.0f) {
                LOG_TEST_CASE("FOGSTART/FOGEND below 0");
                fogValue = std::abs(fogValue);
                Value = *(DWORD*)& fogValue;
            }
        } break;
        case XTL::X_D3DRS_FOGENABLE:
            if (g_LibVersion_D3D8 == 3925) {
                // HACK: Many 3925 games only show a black screen if fog is enabled
                // Initially, this was thought to be bad offsets, but it has been verified to be correct
                // Unitl we find out the true underlying cause, disable fog and carry on
                // Test Cases: Halo, Silent Hill 2.
                LOG_TEST_CASE("Applying 3925 fog disable hack");
                Value = false;
            }
            break;
        case XTL::X_D3DRS_FOGTABLEMODE:
        case XTL::X_D3DRS_FOGDENSITY:
        case XTL::X_D3DRS_RANGEFOGENABLE:
        case XTL::X_D3DRS_LIGHTING:
        case XTL::X_D3DRS_SPECULARENABLE:
        case XTL::X_D3DRS_LOCALVIEWER:
        case XTL::X_D3DRS_COLORVERTEX:
        case XTL::X_D3DRS_SPECULARMATERIALSOURCE:
        case XTL::X_D3DRS_DIFFUSEMATERIALSOURCE:
        case XTL::X_D3DRS_AMBIENTMATERIALSOURCE:
        case XTL::X_D3DRS_EMISSIVEMATERIALSOURCE:
        case XTL::X_D3DRS_AMBIENT:
        case XTL::X_D3DRS_POINTSIZE:
        case XTL::X_D3DRS_POINTSIZE_MIN:
        case XTL::X_D3DRS_POINTSPRITEENABLE:
        case XTL::X_D3DRS_POINTSCALEENABLE:
        case XTL::X_D3DRS_POINTSCALE_A:
        case XTL::X_D3DRS_POINTSCALE_B:
        case XTL::X_D3DRS_POINTSCALE_C:
        case XTL::X_D3DRS_POINTSIZE_MAX:
        case XTL::X_D3DRS_PATCHEDGESTYLE:
        case XTL::X_D3DRS_PATCHSEGMENTS:
            // These render states require no conversion, so we can use them as-is
            break;
        case XTL::X_D3DRS_BACKSPECULARMATERIALSOURCE:
        case XTL::X_D3DRS_BACKDIFFUSEMATERIALSOURCE:
        case XTL::X_D3DRS_BACKAMBIENTMATERIALSOURCE:
        case XTL::X_D3DRS_BACKEMISSIVEMATERIALSOURCE:
        case XTL::X_D3DRS_BACKAMBIENT:
        case XTL::X_D3DRS_SWAPFILTER:
            // These states are unsupported by the host and are ignored (for now)
            return;
        case XTL::X_D3DRS_PRESENTATIONINTERVAL: {
            // Store this as an override for our frame limiter
            // Games can use this to limit certain scenes to a desired target framerate for a specific scene
            // If this value is not set, or is set to 0, the default interval passed to CreateDevice is used
            extern DWORD g_PresentationIntervalOverride;
            g_PresentationIntervalOverride = Value;
        } return;
        case XTL::X_D3DRS_WRAP0:
        case XTL::X_D3DRS_WRAP1:
        case XTL::X_D3DRS_WRAP2:
        case XTL::X_D3DRS_WRAP3: {
            DWORD OldValue = Value;
            Value = 0;

            Value |= (OldValue & 0x00000010) ? D3DWRAPCOORD_0 : 0;
            Value |= (OldValue & 0x00001000) ? D3DWRAPCOORD_1 : 0;
            Value |= (OldValue & 0x00100000) ? D3DWRAPCOORD_2 : 0;
            Value |= (OldValue & 0x01000000) ? D3DWRAPCOORD_3 : 0;
        } break;
        default:
            // Only log missing state if it has a PC counterpart
            if (DxbxRenderStateInfo[State].PC != 0) {
                EmuLog(LOG_LEVEL::WARNING, "ApplyDeferredRenderState(%s, 0x%.08X) is unimplemented!", DxbxRenderStateInfo[State].S, Value);
            }
            return;
    }

    // Skip RenderStates that don't have a defined PC counterpart
    if (DxbxRenderStateInfo[State].PC == 0) {
        return;
    }

    g_pD3DDevice->SetRenderState(DxbxRenderStateInfo[State].PC, Value);
}

void XboxRenderStateConverter::ApplyComplexRenderState(uint32_t State, uint32_t Value)
{
    switch (State) {
        case XTL::X_D3DRS_VERTEXBLEND:
            // convert from Xbox direct3d to PC direct3d enumeration
            if (Value <= 1) {
                Value = Value;
            } else if (Value == 3) {
                Value = 2;
            } else if (Value == 5) {
                Value = 3;
            } else {
                LOG_TEST_CASE("Unsupported D3DVERTEXBLENDFLAGS (%d)");
                return;
            }
            break;
        case XTL::X_D3DRS_FILLMODE:
            Value = EmuXB2PC_D3DFILLMODE(Value);

            if (WireFrameMode > 0) {
                if (WireFrameMode == 1) {
                    Value = D3DFILL_WIREFRAME;
                } else {
                    Value = D3DFILL_POINT;
                }
            }
            break;
        case XTL::X_D3DRS_CULLMODE:
            switch (Value) {
                case XTL::X_D3DCULL_NONE: Value = D3DCULL_NONE; break;
                case XTL::X_D3DCULL_CW: Value = D3DCULL_CW; break;
                case XTL::X_D3DCULL_CCW: Value = D3DCULL_CCW;break;
                default: LOG_TEST_CASE("EmuD3DDevice_SetRenderState_CullMode: Unknown Cullmode");
            }
            break;
        case XTL::X_D3DRS_ZBIAS: {
            FLOAT Biased = static_cast<FLOAT>(Value) * -0.000005f;
            Value = *reinterpret_cast<const DWORD*>(&Biased);
        } break;
        // These states require no conversions, so can just be passed through to the host directly
        case XTL::X_D3DRS_FOGCOLOR:
        case XTL::X_D3DRS_NORMALIZENORMALS:
        case XTL::X_D3DRS_ZENABLE:
        case XTL::X_D3DRS_STENCILENABLE:
        case XTL::X_D3DRS_STENCILFAIL:
        case XTL::X_D3DRS_TEXTUREFACTOR:
        case XTL::X_D3DRS_EDGEANTIALIAS:
        case XTL::X_D3DRS_MULTISAMPLEANTIALIAS:
        case XTL::X_D3DRS_MULTISAMPLEMASK:
            break;
        default:
            // Only log missing state if it has a PC counterpart
            if (DxbxRenderStateInfo[State].PC != 0) {
                EmuLog(LOG_LEVEL::WARNING, "ApplyComplexRenderState(%s, 0x%.08X) is unimplemented!", DxbxRenderStateInfo[State].S, Value);
            }
            return;
    }

    // Skip RenderStates that don't have a defined PC counterpart
    if (DxbxRenderStateInfo[State].PC == 0) {
        return;
    }

    g_pD3DDevice->SetRenderState(DxbxRenderStateInfo[State].PC, Value);
}

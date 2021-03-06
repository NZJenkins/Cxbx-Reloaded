// ******************************************************************
// *
// * proj : OpenXDK
// *
// * desc : Open Source XBox Development Kit
// *
// * file : mm.h
// *
// * note : XBox Kernel *Memory Manager* Declarations
// *
// ******************************************************************
#ifndef XBOXKRNL_MM_H
#define XBOXKRNL_MM_H

XBSYSAPI EXPORTNUM(102) PVOID MmGlobalData[8];

// ******************************************************************
// * MmAllocateContiguousMemory
// ******************************************************************
// *
// * Allocates a range of physically contiguous, cache-aligned
// * memory from nonpaged pool (main pool on xbox).
// *
// ******************************************************************
XBSYSAPI EXPORTNUM(165) PVOID NTAPI MmAllocateContiguousMemory
(
    IN ULONG NumberOfBytes
);

// ******************************************************************
// * MmAllocateContiguousMemoryEx
// ******************************************************************
XBSYSAPI EXPORTNUM(166) PVOID NTAPI MmAllocateContiguousMemoryEx
(
    IN ULONG            NumberOfBytes,
    IN PHYSICAL_ADDRESS LowestAcceptableAddress,
    IN PHYSICAL_ADDRESS HighestAcceptableAddress,
    IN ULONG            Alignment OPTIONAL,
    IN ULONG            ProtectionType
);

// ******************************************************************
// * MmAllocateSystemMemory
// ******************************************************************
XBSYSAPI EXPORTNUM(167) PVOID NTAPI MmAllocateSystemMemory
(
    ULONG NumberOfBytes,
    ULONG Protect
);

// ******************************************************************
// * MmClaimGpuInstanceMemory;
// ******************************************************************
XBSYSAPI EXPORTNUM(168) PVOID NTAPI MmClaimGpuInstanceMemory
(
	IN SIZE_T NumberOfBytes,
	OUT SIZE_T *NumberOfPaddingBytes
);

// ******************************************************************
// * MmCreateKernelStack
// ******************************************************************
XBSYSAPI EXPORTNUM(169) PVOID NTAPI MmCreateKernelStack
(
    IN ULONG	NumberOfBytes,
    IN BOOLEAN	DebuggerThread
);

// ******************************************************************
// * MmDeleteKernelStack
// ******************************************************************
XBSYSAPI EXPORTNUM(170) VOID NTAPI MmDeleteKernelStack
(
    IN PVOID StackBase,
    IN PVOID StackLimit
);

// ******************************************************************
// * MmFreeContiguousMemory
// ******************************************************************
XBSYSAPI EXPORTNUM(171) VOID NTAPI MmFreeContiguousMemory
(
    IN PVOID BaseAddress
);

// ******************************************************************
// * MmFreeSystemMemory
// ******************************************************************
XBSYSAPI EXPORTNUM(172) ULONG NTAPI MmFreeSystemMemory
(
    PVOID BaseAddress,
    ULONG NumberOfBytes
);

// ******************************************************************
// * MmGetPhysicalAddress
// ******************************************************************
XBSYSAPI EXPORTNUM(173) PHYSICAL_ADDRESS NTAPI MmGetPhysicalAddress
(
    IN PVOID   BaseAddress
);

// ******************************************************************
// * MmIsAddressValid
// ******************************************************************
XBSYSAPI EXPORTNUM(174) BOOLEAN NTAPI MmIsAddressValid
(
	IN PVOID   VirtualAddress
);

// ******************************************************************
// * MmLockUnlockBufferPages
// ******************************************************************
XBSYSAPI EXPORTNUM(175) VOID NTAPI MmLockUnlockBufferPages
(
    IN PVOID             BaseAddress,
    IN SIZE_T            NumberOfBytes,
    IN BOOLEAN           UnlockPages
);

// ******************************************************************
// * MmLockUnlockPhysicalPage
// ******************************************************************
XBSYSAPI EXPORTNUM(176) VOID NTAPI MmLockUnlockPhysicalPage
(
	IN ULONG_PTR PhysicalAddress,
	IN BOOLEAN UnlockPage
);

// ******************************************************************
// * MmMapIoSpace
// ******************************************************************
XBSYSAPI EXPORTNUM(177) PVOID NTAPI MmMapIoSpace
(
    IN PHYSICAL_ADDRESS PhysicalAddress,
    IN ULONG            NumberOfBytes,
    IN ULONG            ProtectionType
);

// ******************************************************************
// * MmPersistContiguousMemory
// ******************************************************************
XBSYSAPI EXPORTNUM(178) VOID NTAPI MmPersistContiguousMemory
(
    IN PVOID   BaseAddress,
    IN ULONG   NumberOfBytes,
    IN BOOLEAN Persist
);

// ******************************************************************
// * MmQueryAddressProtect
// ******************************************************************
XBSYSAPI EXPORTNUM(179) ULONG NTAPI MmQueryAddressProtect
(
	IN PVOID VirtualAddress
);

// ******************************************************************
// * MmQueryAllocationSize
// ******************************************************************
XBSYSAPI EXPORTNUM(180) ULONG NTAPI MmQueryAllocationSize
(
    IN PVOID   BaseAddress
);

// ******************************************************************
// * MmQueryStatistics
// ******************************************************************
XBSYSAPI EXPORTNUM(181) NTSTATUS NTAPI MmQueryStatistics
(
    OUT PMM_STATISTICS MemoryStatistics
);

// ******************************************************************
// * MmSetAddressProtect
// ******************************************************************
XBSYSAPI EXPORTNUM(182) VOID NTAPI MmSetAddressProtect
(
    IN PVOID BaseAddress,
    IN ULONG NumberOfBytes,
    IN ULONG NewProtect
);

// ******************************************************************
// * MmUnmapIoSpace
// ******************************************************************
XBSYSAPI EXPORTNUM(183) VOID NTAPI MmUnmapIoSpace
(
    IN PVOID BaseAddress,
    IN ULONG NumberOfBytes
);

// ******************************************************************
// * MmDbgAllocateMemory
// ******************************************************************
XBSYSAPI EXPORTNUM(374) PVOID NTAPI MmDbgAllocateMemory
(
	IN ULONG NumberOfBytes,
	IN ULONG Protect
);

// ******************************************************************
// * MmDbgFreeMemory
// ******************************************************************
XBSYSAPI EXPORTNUM(375) ULONG NTAPI MmDbgFreeMemory
(
	IN PVOID BaseAddress,
	IN ULONG NumberOfBytes
);

// ******************************************************************
// * MmDbgQueryAvailablePages
// ******************************************************************
XBSYSAPI EXPORTNUM(376) ULONG NTAPI MmDbgQueryAvailablePages(void);

// ******************************************************************
// * MmDbgReleaseAddress
// ******************************************************************
XBSYSAPI EXPORTNUM(377) VOID NTAPI MmDbgReleaseAddress
(
	IN PVOID VirtualAddress,
	IN PULONG Opaque
);

// ******************************************************************
// * MmDbgWriteCheck
// ******************************************************************
XBSYSAPI EXPORTNUM(378) PVOID NTAPI MmDbgWriteCheck
(
	IN PVOID VirtualAddress,
	IN PULONG Opaque
);

#endif




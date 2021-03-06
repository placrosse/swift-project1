/*
 * kernel/devices/acpi.swift
 *
 * Created by Simon Evans on 24/01/2016.
 * Copyright © 2016 Simon Evans. All rights reserved.
 *
 * ACPI
 *
 */

typealias SDTPtr = UnsafePointer<acpi_sdt_header>


protocol ACPITable {
    var header: ACPI_SDT { get }
}


struct ACPI_SDT: CustomStringConvertible {
    let signature:  String
    let length:     UInt32
    let revision:   UInt8
    let checksum:   UInt8
    let oemId:      String
    let oemTableId: String
    let oemRev:     UInt32
    let creatorId:  String
    let creatorRev: UInt32

    var description: String {
        return "ACPI: \(signature): \(oemId): \(creatorId): \(oemTableId): rev: \(revision)"
    }


    init(ptr: UnsafePointer<acpi_sdt_header>) {
        signature = makeString(ptr, maxLength: 4)
        length = ptr.pointee.length
        revision = ptr.pointee.revision
        checksum = ptr.pointee.checksum
        oemId = makeString(ptr.advanced(by: 10), maxLength: 6)
        oemTableId = makeString(ptr.advanced(by: 16), maxLength: 8)
        oemRev = ptr.pointee.oem_revision
        creatorId = makeString(ptr.advanced(by: 28), maxLength: 4)
        creatorRev = ptr.pointee.creator_rev
    }
}


struct RSDP1: CustomStringConvertible {
    let signature: String
    let checksum:  UInt8
    let oemId:     String
    let revision:  UInt8
    let rsdtAddr:  UInt32
    var rsdt:      UInt { return UInt(rsdtAddr) }

    var description: String {
        return "ACPI: \(signature): \(oemId): rev: \(revision) "
            + "ptr: \(asHex(rsdt))"
    }


    init(ptr: UnsafePointer<rsdp1_header>) {
        signature = makeString(ptr, maxLength: 8)
        checksum = ptr.pointee.checksum
        oemId = makeString(ptr.advanced(by: 9), maxLength: 6)
        revision = ptr.pointee.revision
        rsdtAddr = ptr.pointee.rsdt_addr
    }
}


struct RSDP2: CustomStringConvertible {
    let signature: String
    let checksum:  UInt8
    let oemId:     String
    let revision:  UInt8
    let rsdtAddr:  UInt32
    let length:    UInt32
    let xsdtAddr:  UInt64
    let checksum2: UInt8
    var rsdt:      UInt { return (xsdtAddr != 0) ? UInt(xsdtAddr) : UInt(rsdtAddr) }

    var description: String {
        return "ACPI: \(signature): \(oemId): rev: \(revision) "
            + "ptr: \(asHex(rsdt))"
    }


    init(ptr: UnsafePointer<rsdp2_header>) {
        signature = makeString(ptr, maxLength: 8)
        checksum = ptr.pointee.rsdp1.checksum
        oemId = makeString(ptr.advanced(by: 9), maxLength: 6)
        revision = ptr.pointee.rsdp1.revision
        rsdtAddr = ptr.pointee.rsdp1.rsdt_addr
        length = ptr.pointee.length
        xsdtAddr = ptr.pointee.xsdt_addr
        checksum2 = ptr.pointee.checksum
    }
}


// FIXME: curently duplicated in smbios.swift
private func makeString(_ rawPtr: UnsafeRawPointer, maxLength: Int) -> String {
    let ptr = rawPtr.bindMemory(to: UInt8.self, capacity: maxLength)
    let buffer = UnsafeBufferPointer(start: ptr, count: maxLength)
    var str = ""

    for ch in buffer {
        if ch != 0 {
            let us = UnicodeScalar(ch)
            if us.isASCII {
                str += String(us)
            }
        }
    }

    return str
}


struct ACPI {

    private(set) var mcfg: MCFG?
    private(set) var facp: FACP?


    init?(rsdp: UnsafeRawPointer) {
        let rsdtPtr = findRSDT(rsdp)
        guard let entries = sdtEntries32(rsdtPtr) else {
            print("ACPI: Cant find any entries")
            return nil
        }

        for entry in entries {
            let rawSDTPtr = mkSDTPtr(UInt(entry))
            let ptr = rawSDTPtr.bindMemory(to: acpi_sdt_header.self, capacity: 1)
            let header = ACPI_SDT(ptr: ptr)
            guard checksum(ptr, size: Int(ptr.pointee.length)) == 0 else {
                printf("ACPI: Entry @ %p has bad chksum\n", ptr)
                continue
            }

            switch header.signature {

            case "MCFG":
                mcfg = MCFG(acpiHeader: header, ptr: ptr)
                print("ACPI: found MCFG")

            case "FACP":
                let ptr = rawSDTPtr.bindMemory(to: acpi_facp_table.self, capacity: 1)
                facp = FACP(acpiHeader: header, ptr: ptr)
                print("ACPI: found FACP")

            default:
                print("ACPI: Unknown table type: \(header.signature)")
            }
        }
    }


    func checksum(_ rawPtr: UnsafeRawPointer, size: Int) -> UInt8 {
        let ptr = rawPtr.bindMemory(to: UInt8.self, capacity: size)
        let region = UnsafeBufferPointer(start: ptr, count: size)
        var csum: UInt8 = 0
        for x in region {
            csum = csum &+ x
        }

        return csum
    }


    private func mkSDTPtr(_ address: UInt) -> UnsafeRawPointer {
        return UnsafeRawPointer(bitPattern: vaddrFromPaddr(address))!
    }


    private func sdtEntries32(_ rawPtr: UnsafeRawPointer) -> UnsafeBufferPointer<UInt32>? {
        let ptr = rawPtr.bindMemory(to: acpi_sdt_header.self, capacity: 1)
        let entryCount = (Int(ptr.pointee.length) - MemoryLayout<acpi_sdt_header>.stride) / MemoryLayout<UInt32>.size

        if entryCount > 0 {
            let entryPtr: UnsafePointer<UInt32> =
                UnsafePointer(bitPattern: ptr.advanced(by: 1).address)!
            return UnsafeBufferPointer(start: entryPtr, count: entryCount)
        } else {
            return nil
        }
    }


    private func findRSDT(_ rawPtr: UnsafeRawPointer) -> UnsafeRawPointer {
        var rsdtAddr: UInt = 0

        let rsdpPtr = rawPtr.bindMemory(to: rsdp1_header.self, capacity: 1)

        if rsdpPtr.pointee.revision == 1 {
            let rsdp2Ptr = rawPtr.bindMemory(to: rsdp2_header.self, capacity: 1)
            rsdtAddr = UInt(rsdp2Ptr.pointee.xsdt_addr)
            if rsdtAddr == 0 {
                rsdtAddr = UInt(rsdp2Ptr.pointee.rsdp1.rsdt_addr)
            }
            //let csum = checksum(UnsafePointer<UInt8>(rsdp2Ptr), size: strideof(RSDP2))
        } else {
            rsdtAddr = UInt(rsdpPtr.pointee.rsdt_addr)
            //let csum = checksum(UnsafePointer<UInt8>(rsdpPtr), size: strideof(RSDP1))
        }
        return mkSDTPtr(rsdtAddr)
    }
}

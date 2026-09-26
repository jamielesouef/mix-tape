// TEMPLATE — response envelope DTO. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/DTO/<Name>ResponseDTO.swift
//
// Most APIs wrap a list in an envelope (`data`, `message`, paging). The
// envelope is its own DTO, one type per file, and the transport returns it
// whole. The repository unwraps and maps; the service never sees it.
// Optional fields stay optional here; nothing is defaulted in a DTO.

struct ExampleFeatureItemsResponseDTO: Decodable {
    let data: [ExampleFeatureItemDTO]
    let message: String?
}

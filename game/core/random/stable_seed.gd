class_name StableSeed
extends RefCounted

const FNV_OFFSET_BASIS_32: int = 2166136261
const FNV_PRIME_32: int = 16777619
const UINT32_MASK: int = 0xFFFFFFFF


static func derive(base_seed: int, ordered_fragments: Array[StringName]) -> int:
	var hash_value: int = FNV_OFFSET_BASIS_32
	for byte_index: int in range(8):
		hash_value = _append_byte(hash_value, (base_seed >> (byte_index * 8)) & 0xFF)

	hash_value = _append_uint32(hash_value, ordered_fragments.size())
	for fragment: StringName in ordered_fragments:
		var encoded_fragment: PackedByteArray = String(fragment).to_utf8_buffer()
		hash_value = _append_uint32(hash_value, encoded_fragment.size())
		for byte_value: int in encoded_fragment:
			hash_value = _append_byte(hash_value, byte_value)
	return hash_value


static func create_rng(base_seed: int, ordered_fragments: Array[StringName]) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = derive(base_seed, ordered_fragments)
	return random


static func _append_uint32(hash_value: int, value: int) -> int:
	var updated_hash: int = hash_value
	for byte_index: int in range(4):
		updated_hash = _append_byte(updated_hash, (value >> (byte_index * 8)) & 0xFF)
	return updated_hash


static func _append_byte(hash_value: int, byte_value: int) -> int:
	return ((hash_value ^ byte_value) * FNV_PRIME_32) & UINT32_MASK

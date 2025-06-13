class DeliveryLocation {
  final String id;
  final String name;
  final String address;
  final double deliveryFee;
  final bool isDefault;

  DeliveryLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.deliveryFee,
    this.isDefault = false,
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      id: json['\$id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      deliveryFee: json['deliveryFee'] is int 
          ? (json['deliveryFee'] as int).toDouble() 
          : double.tryParse(json['deliveryFee'].toString()) ?? 0.0,
      isDefault: json['isDefault'] ?? false,
    );
  }
}

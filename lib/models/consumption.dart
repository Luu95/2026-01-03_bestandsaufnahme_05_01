class Consumption {
  List<int> electricityKWh;
  List<int> gasKWh;

  Consumption({
    required this.electricityKWh,
    required this.gasKWh,
  });

  factory Consumption.fromJson(Map<String, dynamic> json) => Consumption(
    electricityKWh: List<int>.from(json['electricity_kWh'] ?? []),
    gasKWh: List<int>.from(json['gas_kWh'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'electricity_kWh': electricityKWh,
    'gas_kWh': gasKWh,
  };
}

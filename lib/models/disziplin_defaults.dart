import 'package:flutter/material.dart';
import 'disziplin_schnittstelle.dart';

/// Standard-Disziplinen (nur Label, Icon, Farbe). Schema bleibt leer und
/// wird ausschließlich aus dem CSV-Import oder im Schema-Editor aufgebaut.
Disziplin defaultHeizung() {
  return Disziplin(
    label: 'Heizung',
    icon: Icons.local_fire_department,
    color: Color.fromRGBO(255, 165, 0, 0.9),
    schema: [],
  );
}

Disziplin defaultLueftung() {
  return Disziplin(
    label: 'Lüftung',
    icon: Icons.air,
    color: Color.fromRGBO(0, 0, 255, 0.8),
    schema: [],
  );
}

Disziplin defaultKlimaanlage() {
  return Disziplin(
    label: 'Klimaanlage',
    icon: Icons.ac_unit,
    color: Color.fromRGBO(0, 255, 255, 0.8),
    schema: [],
  );
}

Disziplin defaultBeleuchtung() {
  return Disziplin(
    label: 'Beleuchtung',
    icon: Icons.lightbulb,
    color: Color.fromRGBO(255, 255, 0, 0.9),
    schema: [],
  );
}

Disziplin defaultPhotovoltaikanlage() {
  return Disziplin(
    label: 'Photovoltaikanlage',
    icon: Icons.solar_power,
    color: Color.fromRGBO(255, 204, 0, 0.8),
    schema: [],
  );
}

Disziplin defaultWaermepumpe() {
  return Disziplin(
    label: 'Wärmepumpe',
    icon: Icons.pool,
    color: Color.fromRGBO(0, 255, 0, 0.8),
    schema: [],
  );
}

Disziplin defaultWarmwasserspeicher() {
  return Disziplin(
    label: 'Warmwasserspeicher',
    icon: Icons.water_damage,
    color: Color.fromRGBO(0, 0, 255, 0.7),
    schema: [],
  );
}

Disziplin defaultFassade() {
  return Disziplin(
    label: 'Fassade',
    icon: Icons.house,
    color: Color.fromRGBO(255, 0, 0, 0.8),
    schema: [],
  );
}

Disziplin defaultDach() {
  return Disziplin(
    label: 'Dach',
    icon: Icons.roofing,
    color: Color.fromRGBO(100, 100, 100, 0.8),
    schema: [],
  );
}

Disziplin defaultFenster() {
  return Disziplin(
    label: 'Fenster',
    icon: Icons.window,
    color: Color.fromRGBO(50, 50, 255, 0.7),
    schema: [],
  );
}

Disziplin defaultElektroinstallation() {
  return Disziplin(
    label: 'Elektroinstallation',
    icon: Icons.electric_car,
    color: Color.fromRGBO(255, 255, 255, 0.8),
    schema: [],
  );
}

Disziplin placeholder() {
  return Disziplin(
    label: 'Neue Disziplin',
    icon: Icons.new_releases,
    color: Colors.grey,
    schema: [],
  );
}

List<Disziplin> getDefaultDisziplinen() {
  return [
    defaultHeizung(),
    defaultLueftung(),
    defaultKlimaanlage(),
    defaultBeleuchtung(),
    defaultPhotovoltaikanlage(),
    defaultWaermepumpe(),
    defaultWarmwasserspeicher(),
    defaultFassade(),
    defaultDach(),
    defaultFenster(),
    defaultElektroinstallation(),
  ];
}

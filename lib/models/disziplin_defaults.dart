import 'package:flutter/material.dart';
import 'disziplin_schnittstelle.dart';

/// Standard-Disziplinen (Werkzeuge)
Disziplin defaultHeizung() {
  return Disziplin(
    label: 'Heizung',
    icon: Icons.local_fire_department,
    color: Color.fromRGBO(255, 165, 0, 0.9),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'leistung', 'label': 'Leistung (kW)', 'type': 'int'},
      {'key': 'brennstoff', 'label': 'Brennstofftyp', 'type': 'string'},
      {'key': 'cop', 'label': 'COP (Leistungszahl)', 'type': 'int'},
      {'key': 'jahresarbeitszahl', 'label': 'Jahresarbeitszahl (JAZ)', 'type': 'int'},
      {'key': 'pufferspeicher', 'label': 'Pufferspeicher (l)', 'type': 'int'},
    ],
  );
}

Disziplin defaultLueftung() {
  return Disziplin(
    label: 'Lüftung',
    icon: Icons.air,
    color: Color.fromRGBO(0, 0, 255, 0.8),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'volumenstrom', 'label': 'Volumenstrom (m³/h)', 'type': 'int'},
      {'key': 'luftwechselrate', 'label': 'Luftwechselrate (h⁻¹)', 'type': 'int'},
      {'key': 'filtertyp', 'label': 'Filtertyp', 'type': 'string'},
      {'key': 'energieverbrauch', 'label': 'Energieverbrauch (kWh)', 'type': 'int'},
    ],
  );
}

Disziplin defaultKlimaanlage() {
  return Disziplin(
    label: 'Klimaanlage',
    icon: Icons.ac_unit,
    color: Color.fromRGBO(0, 255, 255, 0.8),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'leistung', 'label': 'Leistung (kW)', 'type': 'int'},
      {'key': 'energieverbrauch', 'label': 'Energieverbrauch (kWh)', 'type': 'int'},
      {'key': 'temperaturbereich', 'label': 'Temperaturbereich (°C)', 'type': 'string'},
      {'key': 'betriebsstunden', 'label': 'Betriebsstunden', 'type': 'int'},
      {'key': 'eer', 'label': 'EER (Energie-Effizienz-Verhältnis)', 'type': 'int'},
    ],
  );
}

Disziplin defaultBeleuchtung() {
  return Disziplin(
    label: 'Beleuchtung',
    icon: Icons.lightbulb,
    color: Color.fromRGBO(255, 255, 0, 0.9),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'anzahl_lampen', 'label': 'Anzahl Lampen', 'type': 'int'},
      {'key': 'lampentyp', 'label': 'Lampentyp', 'type': 'string'},
      {'key': 'energieverbrauch', 'label': 'Energieverbrauch (kWh)', 'type': 'int'},
      {'key': 'betriebsstunden', 'label': 'Betriebsstunden', 'type': 'int'},
      {'key': 'effizienzklasse', 'label': 'Effizienzklasse', 'type': 'string'},
    ],
  );
}

Disziplin defaultPhotovoltaikanlage() {
  return Disziplin(
    label: 'Photovoltaikanlage',
    icon: Icons.solar_power,
    color: Color.fromRGBO(255, 204, 0, 0.8),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'leistung', 'label': 'Leistung (kWp)', 'type': 'int'},
      {'key': 'modultyp', 'label': 'Modultyp', 'type': 'string'},
      {'key': 'energieproduktion', 'label': 'Energieproduktion (kWh)', 'type': 'int'},
      {'key': 'flachneigung', 'label': 'Neigungswinkel (°)', 'type': 'int'},
      {'key': 'neigungswinkel', 'label': 'Neigungswinkel (°)', 'type': 'int'},
      {'key': 'ausrichtung', 'label': 'Ausrichtung', 'type': 'string'},
    ],
  );
}

Disziplin defaultWaermepumpe() {
  return Disziplin(
    label: 'Wärmepumpe',
    icon: Icons.pool,
    color: Color.fromRGBO(0, 255, 0, 0.8),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'leistung', 'label': 'Leistung (kW)', 'type': 'int'},
      {'key': 'effizienz', 'label': 'COP (Leistungszahl)', 'type': 'int'},
      {'key': 'jahresarbeitszahl', 'label': 'Jahresarbeitszahl (JAZ)', 'type': 'int'},
      {'key': 'brennstoff', 'label': 'Brennstofftyp', 'type': 'string'},
      {'key': 'betriebsstunden', 'label': 'Betriebsstunden', 'type': 'int'},
      {'key': 'pufferspeicher', 'label': 'Pufferspeicher (l)', 'type': 'int'},
    ],
  );
}

Disziplin defaultWarmwasserspeicher() {
  return Disziplin(
    label: 'Warmwasserspeicher',
    icon: Icons.water_damage,
    color: Color.fromRGBO(0, 0, 255, 0.7),
    schema: [
      {'key': 'hersteller', 'label': 'Hersteller', 'type': 'string'},
      {'key': 'typ', 'label': 'Typ/Modell', 'type': 'string'},
      {'key': 'baujahr', 'label': 'Baujahr', 'type': 'int'},
      {'key': 'kapazitaet', 'label': 'Speicherkapazität (l)', 'type': 'int'},
      {'key': 'temperatur', 'label': 'Temperatur (°C)', 'type': 'int'},
      {'key': 'energieverbrauch', 'label': 'Energieverbrauch (kWh)', 'type': 'int'},
      {'key': 'betriebsstunden', 'label': 'Betriebsstunden', 'type': 'int'},
      {'key': 'verteilung', 'label': 'Verteilungssystem', 'type': 'string'},
    ],
  );
}

Disziplin defaultFassade() {
  return Disziplin(
    label: 'Fassade',
    icon: Icons.house,
    color: Color.fromRGBO(255, 0, 0, 0.8),
    schema: [
      {'key': 'material', 'label': 'Material', 'type': 'string'},
      {'key': 'flach', 'label': 'Fläche (m²)', 'type': 'int'},
      {'key': 'u_wert', 'label': 'U-Wert (W/m²K)', 'type': 'int'},
      {'key': 'ausrichtung', 'label': 'Ausrichtung', 'type': 'string'},
      {'key': 'bauteilqualitaet', 'label': 'Bauteilqualität', 'type': 'string'},
    ],
  );
}

Disziplin defaultDach() {
  return Disziplin(
    label: 'Dach',
    icon: Icons.roofing,
    color: Color.fromRGBO(100, 100, 100, 0.8),
    schema: [
      {'key': 'material', 'label': 'Material', 'type': 'string'},
      {'key': 'flach', 'label': 'Fläche (m²)', 'type': 'int'},
      {'key': 'u_wert', 'label': 'U-Wert (W/m²K)', 'type': 'int'},
      {'key': 'neigung', 'label': 'Neigungswinkel (°)', 'type': 'int'},
      {'key': 'bauteilqualitaet', 'label': 'Bauteilqualität', 'type': 'string'},
    ],
  );
}

Disziplin defaultFenster() {
  return Disziplin(
    label: 'Fenster',
    icon: Icons.window,
    color: Color.fromRGBO(50, 50, 255, 0.7),
    schema: [
      {'key': 'anzahl', 'label': 'Anzahl Fenster', 'type': 'int'},
      {'key': 'material', 'label': 'Material', 'type': 'string'},
      {'key': 'rahmen', 'label': 'Rahmenmaterial', 'type': 'string'},
      {'key': 'u_wert', 'label': 'U-Wert (W/m²K)', 'type': 'int'},
      {'key': 'bauteilqualitaet', 'label': 'Bauteilqualität', 'type': 'string'},
    ],
  );
}

Disziplin defaultElektroinstallation() {
  return Disziplin(
    label: 'Elektroinstallation',
    icon: Icons.electric_car,
    color: Color.fromRGBO(255, 255, 255, 0.8),
    schema: [
      {'key': 'stromverbrauch', 'label': 'Stromverbrauch (kWh)', 'type': 'int'},
      {'key': 'anschluss', 'label': 'Anschlusswert (kW)', 'type': 'int'},
      {'key': 'belegung', 'label': 'Belegung (Anzahl Geräte)', 'type': 'int'},
      {'key': 'installationstyp', 'label': 'Installationstyp', 'type': 'string'},
      {'key': 'effizienzklasse', 'label': 'Effizienzklasse', 'type': 'string'},
    ],
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

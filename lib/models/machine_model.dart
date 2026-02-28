import 'package:flutter/material.dart';

class Machine {
  final int id;
  final String productId;
  final String type;
  final double airTemp;
  final double processTemp;
  final double rpm;
  final double torque;
  final double toolWear;
  double failureProbability; // 0.0 to 1.0, mutable so we can update after prediction

  Machine({
    required this.id,
    required this.productId,
    required this.type,
    required this.airTemp,
    required this.processTemp,
    required this.rpm,
    required this.torque,
    required this.toolWear,
    required this.failureProbability,
  });

  // user-friendly name for display combining product and type
  String get name => '$productId ($type)';

  // quick derived values
  double get powerEstimate => rpm * torque; // simple product, same as backend
  double get tempDifference => processTemp - airTemp;

  /// return a copy of this object with any overridden fields.
  Machine copyWith({
    int? id,
    String? productId,
    String? type,
    double? airTemp,
    double? processTemp,
    double? rpm,
    double? torque,
    double? toolWear,
    double? failureProbability,
  }) {
    return Machine(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      airTemp: airTemp ?? this.airTemp,
      processTemp: processTemp ?? this.processTemp,
      rpm: rpm ?? this.rpm,
      torque: torque ?? this.torque,
      toolWear: toolWear ?? this.toolWear,
      failureProbability: failureProbability ?? this.failureProbability,
    );
  }

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'],
      productId: json['Product ID'] ?? json['productId'] ?? '',
      type: json['Type'] ?? json['type'] ?? '',
      airTemp: (json['Air temperature [K]'] ?? json['airTemp'] ?? 0).toDouble(),
      processTemp: (json['Process temperature [K]'] ?? json['processTemp'] ?? 0).toDouble(),
      rpm: (json['Rotational speed [rpm]'] ?? json['rpm'] ?? 0).toDouble(),
      torque: (json['Torque [Nm]'] ?? json['torque'] ?? 0).toDouble(),
      toolWear: (json['Tool wear [min]'] ?? json['toolWear'] ?? 0).toDouble(),
      failureProbability: (json['prob'] ?? json['failureProbability'] ?? json['probability'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'type': type,
      'airTemp': airTemp,
      'processTemp': processTemp,
      'rpm': rpm,
      'torque': torque,
      'toolWear': toolWear,
      'prob': failureProbability,
    };
  }

  // determine a colour that corresponds to risk level
  Color get statusColor {
    if (failureProbability > 0.8) return Colors.redAccent;
    if (failureProbability > 0.3) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

}


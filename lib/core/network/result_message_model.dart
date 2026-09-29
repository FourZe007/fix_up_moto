import 'package:json_annotation/json_annotation.dart';

part 'result_message_model.g.dart';

/// Shape of a SAMP write/mutation endpoint's `Data[0]` when it has no record
/// of its own to hand back — just a single confirmation field, e.g.
/// `{"ResultMessage": "B 1234 ML"}`. Generic and reusable across any feature
/// whose backend call returns this same shape, rather than tied to one.
@JsonSerializable()
class ResultMessageModel {
  @JsonKey(name: 'ResultMessage')
  final String resultMessage;

  const ResultMessageModel({required this.resultMessage});

  factory ResultMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ResultMessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$ResultMessageModelToJson(this);
}

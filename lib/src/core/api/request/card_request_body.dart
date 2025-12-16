import 'dart:async';
import 'dart:convert';

import 'package:rexpay/rexpay.dart';
import 'package:rexpay/src/core/common/crypto.dart';
import 'package:rexpay/src/models/charge.dart';

// class CardRequestBody extends BaseRequestBody {
class CardRequestBody {
  static const String fieldClientData = "clientdata";
  static const String fieldLast4 = "last4";
  static const String fieldAccessCode = "access_code";
  static const String fieldEmail = "email";
  static const String fieldAmount = "amount";
  static const String fieldReference = "reference";
  static const String fieldSubAccount = "subaccount";
  static const String fieldTransactionCharge = "transaction_charge";
  static const String fieldBearer = "bearer";
  static const String fieldHandle = "handle";
  static const String fieldMetadata = "metadata";
  static const String fieldCurrency = "currency";
  static const String fieldPlan = "plan";

  AuthKeys authKeys;
  String? _clientData;
  String? _last4;
  String? _accessCode;
  String? _email;
  String _amount;
  String? _reference;
  String? _transactionCharge;
  String? _metadata;
  String? _currency;
  String? _plan;
  String? _callBackUrl;
  String? _customerName;
  String? _paymentId;
  String? _otp;
  PaymentCard? _card;
  Map<String, String?>? _additionalParameters;

  CardRequestBody(Charge charge, this.authKeys)
      : _last4 = charge.card!.last4Digits,
        _email = charge.email,
        _amount = (charge.amount / 100).toStringAsFixed(2),
        _reference = charge.reference,
        _transactionCharge =
            charge.transactionCharge != null && charge.transactionCharge! > 0
                ? (charge.transactionCharge! / 100).toStringAsFixed(2)
                : null,
        _metadata = charge.metadata,
        _plan = charge.plan,
        _card = charge.card,
        _currency = charge.currency,
        _customerName = charge.customerName,
        _callBackUrl = charge.callBackUrl,
        _additionalParameters = charge.additionalParameters;

  static Future<CardRequestBody> getChargeRequestBody(
      AuthKeys authKeys, Charge charge) async {
    return CardRequestBody(charge, authKeys);
  }

  String? get paymentId => _paymentId ?? "";
  String? get otp => _otp ?? "";

  set otp(String? value) {
    _otp = value;
    print('[CardRequestBody] otp set. length=${value?.length}');
  }

  set paymentId(String? value) {
    _paymentId = value;
    print('[CardRequestBody] paymentId set: $value');
  }

  Map<String, dynamic> toChargeCardJson2() {
    return {
      "encryptedRequest": _customerName,
    };
  }

  Future<Map<String, dynamic>> toChargeCardJson(AuthKeys authKeys) async {
    String encodedString = jsonEncode({
      "reference": _reference,
      "amount": _amount,
      "customerId": _email,
      "cardDetails": {
        "authDataVersion": "1",
        "pan": _card?.number ?? "",
        "expiryDate": "${_card?.expiryMonth}${_card?.expiryYear}",
        "cvv2": _card?.cvc ?? "",
        "pin": _card?.pin ?? "",
      }
    });

    String enc = await Crypto.encrypt(encodedString, authKeys.rexPayPublicKey);
    return {
      "encryptedRequest": enc,
    };
  }

  Future<Map<String, dynamic>> toAuthorizePaymentJson(AuthKeys authKeys) async {
    print(
        '[CardRequestBody] building authorize payload. paymentId=$_paymentId, hasOtp=${_otp != null && _otp!.isNotEmpty}');
    String encodedString = jsonEncode({"paymentId": _paymentId, "otp": _otp});

    String enc = await Crypto.encrypt(encodedString, authKeys.rexPayPublicKey);
    return {
      "encryptedRequest": enc,
    };
  }

  Map<String, dynamic> toInitialJson() {
    return {
      "reference": _reference,
      "amount": _amount,
      "currency": _currency,
      "userId": _email ?? "",
      "callbackUrl": _callBackUrl ?? "",
      "metadata": {
        "email": _email ?? "",
        "customerName": _customerName ?? "",
      }
    };
  }

  Map<String, String?> paramsMap() {
    // set values will override additional params provided
    Map<String, String?> params = _additionalParameters!;
    params[fieldClientData] = _clientData;
    params[fieldLast4] = _last4;
    params[fieldAccessCode] = _accessCode;
    params[fieldEmail] = _email;
    params[fieldAmount] = _amount;
    params[fieldReference] = _reference;
    params[fieldTransactionCharge] = _transactionCharge;
    params[fieldMetadata] = _metadata;
    params[fieldPlan] = _plan;
    params[fieldCurrency] = _currency;

    return params..removeWhere((key, value) => value == null || value.isEmpty);
  }
}

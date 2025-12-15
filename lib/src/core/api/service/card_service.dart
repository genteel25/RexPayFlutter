import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:rexpay/src/core/api/model/transaction_api_response.dart';
import 'package:rexpay/src/core/api/request/card_request_body.dart';
import 'package:rexpay/src/core/api/service/base_service.dart';
import 'package:rexpay/src/core/api/service/contracts/cards_service_contract.dart';
import 'package:rexpay/src/core/api/service/custom_exception.dart';
import 'package:rexpay/src/core/common/crypto.dart';
import 'package:rexpay/src/core/common/exceptions.dart';
import 'package:rexpay/src/core/common/my_strings.dart';
import 'package:rexpay/src/core/constants/constants.dart';
import 'package:rexpay/src/models/auth_keys.dart';

class CardService with BaseApiService implements CardServiceContract {
  @override
  Future<TransactionApiResponse> chargeCard(CardRequestBody? credentials, AuthKeys authKeys) async {
    try {
      Map<String, dynamic> cre = await credentials!.toChargeCardJson(authKeys);
      Response response = await apiPostRequests(
        "${getBaseUrl(authKeys.mode)}cps/v1/chargeCard",
        cre,
        header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
      );

      var body = response.data;

      var statusCode = response.statusCode;

      switch (statusCode) {
        case HttpStatus.ok:
          return TransactionApiResponse.fromChargeCardMap(await decryptCode(body["encryptedResponse"], authKeys));
        case HttpStatus.gatewayTimeout:
          throw ChargeException('Gateway timeout error');
        default:
          throw ChargeException(Strings.unKnownResponse);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> decryptCode(String value, AuthKeys authKeys) async {
    String deCrypt = await Crypto.decrypt(value, authKeys);
    Map<String, dynamic> decMap = Map<String, dynamic>.from(jsonDecode(deCrypt));
    return decMap;
  }

  @override
  Future<TransactionApiResponse> authorizeCharge(CardRequestBody? credentials, AuthKeys authKeys) async {
    print('[CardService] authorizeCharge called. mode=${authKeys.mode}');
    Map<String, dynamic> cre = await credentials!.toAuthorizePaymentJson(authKeys);
    print('[CardService] Sending OTP authorizeTransaction request to ${getBaseUrl(authKeys.mode)}cps/v1/authorizeTransaction');

    Response response = await apiPostRequests(
      "${getBaseUrl(authKeys.mode)}cps/v1/authorizeTransaction",
      cre,
      header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
    );

    var body = response.data;

    var statusCode = response.statusCode;
    print('[CardService] authorizeCharge response received. statusCode=$statusCode');
    if (statusCode == HttpStatus.ok) {
      Map<String, dynamic> responseBody = await decryptCode(body["encryptedResponse"], authKeys);
      print('[CardService] authorizeCharge decrypted response keys: ${responseBody.keys.toList()}');
      return TransactionApiResponse.fromAuthorizeCardMap(responseBody);
    } else {
      print('[CardService] authorizeCharge failed. statusCode=$statusCode, body=$body');
      throw CustomException('validate charge transaction failed with '
          'status code: $statusCode and response: $body');
    }
  }

  @override
  Future<TransactionApiResponse> createPayment(CardRequestBody? credentials, AuthKeys authKeys) async {
    try {
      Response response = await apiPostRequests(
        "${getBaseUrl(authKeys.mode,type: 'pgs')}pgs/payment/v2/createPayment",
        credentials!.toInitialJson(),
        header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
      );
      var body = response.data;

      var statusCode = response.statusCode;
      if (statusCode == HttpStatus.ok) {
        return TransactionApiResponse.fromCreateTransaction(body);
      } else {
        throw CustomException('Card transaction intiation failed with '
            'status code: $statusCode and response: $body');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TransactionApiResponse> insertPublicKey(AuthKeys authKeys) async {
    try {
      Response response = await apiPostRequests(
        "${getBaseUrl(authKeys.mode, type: 'pgs')}pgs/clients/v1/publicKey",
        {"clientId": authKeys.username, "publicKey": authKeys.publicKey},
        header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
      );
      var body = response.data;

      var statusCode = response.statusCode;
      if (statusCode == HttpStatus.ok) {
        return TransactionApiResponse.fromUploadeKeyMap({"status": "UPLOADED"});
      } else {
        throw CustomException('Key upload failed with '
            'status code: $statusCode and response: $body');
      }
    } catch (e) {
      rethrow;
    }
  }

  String getBaseUrl(Mode mode, {String type = 'cps'}) {
    if (mode == Mode.live) {
      if (type == 'pgs') {
         return "$LIVE_PGS_BASE_URL/api/";
      }
      return "$LIVE_CPS_BASE_URL/api/";
    }
    return "$TEST_BASE_URL/api/";
  }
}

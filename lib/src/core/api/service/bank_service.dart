import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:rexpay/src/core/api/model/transaction_api_response.dart';
import 'package:rexpay/src/core/api/request/bank_charge_request_body.dart';
import 'package:rexpay/src/core/api/service/base_service.dart';
import 'package:rexpay/src/core/api/service/contracts/banks_service_contract.dart';
import 'package:rexpay/src/core/common/exceptions.dart';
import 'package:rexpay/src/core/constants/constants.dart';
import 'package:rexpay/src/models/auth_keys.dart';

class BankService with BaseApiService implements BankServiceContract {
  @override
  Future<TransactionApiResponse> getTransactionStatus(String transRef, AuthKeys authKeys) async {
    print('[BankService] getTransactionStatus called. reference=$transRef, mode=${authKeys.mode}');
    Response response = await apiPostRequests(
      "${getBaseUrl(authKeys.mode)}cps/v1/getTransactionStatus",
      {"transactionReference": transRef},
      header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
    );

    var body = response.data;
    var statusCode = response.statusCode;

    print('[BankService] getTransactionStatus response. statusCode=$statusCode');
    if (statusCode == HttpStatus.ok) {
      final result = TransactionApiResponse.fromGetTransactionStatus(body!);
      print('[BankService] getTransactionStatus parsed response. status=${result.status}, responseDescription=${result.responseDescription}, responseCode=${result.responseCode}');
      return result;
    } else {
      print('[BankService] getTransactionStatus failed. statusCode=$statusCode, body=$body');
      throw ChargeException('Bank transaction failed with '
          'status code: $statusCode and response: $body');
    }
  }

  @override
  Future<TransactionApiResponse> chargeBank(BankChargeRequestBody? credentials, AuthKeys authKeys) async {
    try {
      print('[BankService] chargeBank called. mode=${authKeys.mode}');
      Response response = await apiPostRequests(
        "${getBaseUrl(authKeys.mode)}cps/v1/initiateBankTransfer",
        credentials!.toChargeBankJson(),
        header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
      );

      var body = response.data;
      var statusCode = response.statusCode;

      print('[BankService] chargeBank response. statusCode=$statusCode');
      if (statusCode == HttpStatus.ok) {
        final result = TransactionApiResponse.fromChargeCardMap(body!);
        print('[BankService] chargeBank parsed response. responseCode=${result.responseCode}, responseDescription=${result.responseDescription}, bankName=${result.bankName}, accountNumber=${result.accountNumber}');
        return result;
      } else {
        print('[BankService] chargeBank failed. statusCode=$statusCode, body=$body');
        throw ChargeException('Bank transaction failed with '
            'status code: $statusCode and response: $body');
      }
    } catch (e) {
      print('[BankService] chargeBank threw error: $e');
      rethrow;
    }
  }

  @override
  Future<TransactionApiResponse> createPayment(BankChargeRequestBody? credentials, AuthKeys authKeys) async {
    try {
      print('[BankService] createPayment called. mode=${authKeys.mode}');
      Response response = await apiPostRequests(
        "${getBaseUrl(authKeys.mode, type: 'pgs')}pgs/payment/v2/createPayment",
        credentials!.toInitialJson(),
        header: {'authorization': 'Basic ${base64Encode(utf8.encode('${authKeys.username}:${authKeys.password}'))}'},
      );

      var body = response.data;
      var statusCode = response.statusCode;

      print('[BankService] createPayment response. statusCode=$statusCode');
      if (statusCode == HttpStatus.ok) {
        final result = TransactionApiResponse.fromCreateTransaction(body!);
        print('[BankService] createPayment parsed response. status=${result.status}, reference=${result.reference}, clientId=${result.clientId}');
        return result;
      } else {
        print('[BankService] createPayment failed. statusCode=$statusCode, body=$body');
        throw ChargeException('Bank transaction failed with '
            'status code: $statusCode and response: $body');
      }
    } catch (e) {
      print('[BankService] createPayment threw error: $e');
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

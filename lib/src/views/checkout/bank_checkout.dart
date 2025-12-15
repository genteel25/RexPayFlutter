import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:rexpay/rexpay.dart';
import 'package:rexpay/src/core/api/model/transaction_api_response.dart';
import 'package:rexpay/src/core/api/request/bank_charge_request_body.dart';
import 'package:rexpay/src/core/api/service/bank_service.dart';
import 'package:rexpay/src/core/api/service/contracts/banks_service_contract.dart';
import 'package:rexpay/src/core/api/service/custom_exception.dart';
import 'package:rexpay/src/core/common/rexpay.dart';
import 'package:rexpay/src/core/constants/colors.dart';
import 'package:rexpay/src/models/bank.dart';
import 'package:rexpay/src/models/charge.dart';
import 'package:rexpay/src/models/checkout_response.dart';
import 'package:rexpay/src/transaction/bank_transaction_manager.dart';
import 'package:rexpay/src/views/buttons.dart';
import 'package:rexpay/src/views/checkout/base_checkout.dart';
import 'package:rexpay/src/views/checkout/checkout_widget.dart';
import 'package:rexpay/src/views/common/extensions.dart';
import 'package:rexpay/src/views/input/account_field.dart';

class BankCheckout extends StatefulWidget {
  final Charge charge;
  final OnResponse<CheckoutResponse> onResponse;
  final ValueChanged<bool> onProcessingChange;
  final BankServiceContract service;
  final AuthKeys authKeys;

  BankCheckout({
    required this.charge,
    required this.onResponse,
    required this.onProcessingChange,
    required this.service,
    required this.authKeys,
  });

  @override
  _BankCheckoutState createState() => _BankCheckoutState(onResponse);
}

class _BankCheckoutState extends BaseCheckoutMethodState<BankCheckout> {
  late AnimationController _controller;
  late Animation<double> _animation;
  late BankChargeRequestBody _bankChargeRequestBody;
  BankAccount? _account;
  var _loading = false;
  bool _isLoadingBankDetails = false;
  bool _isAccountGenerated = false;
  String error = "";

  _BankCheckoutState(OnResponse<CheckoutResponse> onResponse) : super(onResponse, CheckoutMethod.bank);

  @override
  void initState() {
    _bankChargeRequestBody = BankChargeRequestBody(widget.charge);
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.ease,
      ),
    );
    _animation.addListener(_rebuild);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget buildAnimatedChild() {
    if (_isAccountGenerated == true) {
      return _getCompleteUI();
    }
    return _getInitialUI();
  }

  Widget _getInitialUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(
          height: 10.0,
        ),
        if (error != "")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1)),
            child: Center(
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.0,
                  color: AppColors.red,
                ),
              ),
            ),
          ),
        const Text(
          'Kindly click the button to get account details',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
        ),
        const SizedBox(
          height: 20.0,
        ),
        AccentButton(
          onPressed: _getPaymentBankDetails,
          showProgress: _isLoadingBankDetails,
          text: 'Get Account Details',
          color: AppColors.primaryColor,
        ),
        const SizedBox(
          height: 20.0,
        ),
      ],
    );
  }

  Widget _getCompleteUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (error != "")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1)),
            child: Center(
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.0,
                  color: AppColors.red,
                ),
              ),
            ),
          ),
        const Text(
          'Kindly proceed to your banking app mobile/internet to complete your bank transfer',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
        ),
        const SizedBox(height: 10),
        const Text(
          'Please note the account number expires in 30 minutes',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
        ),
        Container(
          width: double.infinity,
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(20),
          color: AppColors.grey,
          child: Column(
            children: [
              const Text(
                'Bank:',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
              ),
              const SizedBox(height: 5),
              Text(
                _account?.bank?.name ?? "",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
              const SizedBox(height: 10),
              const Text(
                'Account Name:',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
              ),
              const SizedBox(height: 5),
              Text(
                _account?.accountName ?? "",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
              const SizedBox(height: 10),
              const Text(
                'Account number:',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
              ),
              const SizedBox(height: 5),
              Text(
                _account?.number ?? "5678899",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AccentButton(
          onPressed: confirmPayment,
          showProgress: _loading,
          text: 'I have completed the transfer',
          color: AppColors.primaryColor,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _getPaymentBankDetails() async {
    TransactionApiResponse? response;
    try {
      setState(() {
        _isLoadingBankDetails = true;
        _isAccountGenerated = false;
        error = "";
      });

      print('[BankCheckout] Starting createPayment for bank transfer. reference=${widget.charge.reference}, amount=${widget.charge.amount}');
      response = await widget.service.createPayment(_bankChargeRequestBody, widget.authKeys);

      if (response.status == "CREATED") {
        print('[BankCheckout] createPayment succeeded. status=${response.status}, reference=${response.reference}, clientId=${response.clientId}');
        response = await widget.service.chargeBank(_bankChargeRequestBody, widget.authKeys);

        if (response.responseDescription == "Success") {
          print('[BankCheckout] chargeBank succeeded. bankName=${response.bankName}, accountNumber=${response.accountNumber}, accountName=${response.accountName}');
          setState(() {
            _account = BankAccount(Bank(response?.bankName ?? "", 0, "", response?.bankName ?? ""), response!.accountNumber, response.accountName);
            _isAccountGenerated = true;
          });
          widget.onProcessingChange(true);
        } else {
          print('[BankCheckout] chargeBank returned non-success. responseCode=${response.responseCode}, responseDescription=${response.responseDescription}, rawResponse=${response.rawResponse}');
          setState(() {
            error = response?.responseDescription ?? response?.message ?? 'Unable to generate bank account details. Please try again.';
          });
        }
      } else {
        print('[BankCheckout] createPayment returned unexpected status=${response.status}, rawResponse=${response.rawResponse}');
        setState(() {
          error = response?.message ?? 'Unable to initiate bank transfer payment. Please try again.';
        });
      }
    } on CustomException catch (e) {
      setState(() {
        error = e.message;
      });
      print('[BankCheckout] CustomException in _getPaymentBankDetails: ${e.message}');
    } catch (e) {
      print('[BankCheckout] Unexpected error in _getPaymentBankDetails: $e');
    }

    setState(() {
      _isLoadingBankDetails = false;
      print('[BankCheckout] _getPaymentBankDetails finished. isLoadingBankDetails set to false.');
    });
  }

  void confirmPayment() async {
    TransactionApiResponse? response;
    try {
      setState(() {
        _loading = true;
        error = "";
      });

      print('[BankCheckout] confirmPayment tapped. reference=${widget.charge.reference}');
      response = await widget.service.getTransactionStatus(widget.charge.reference!, widget.authKeys);

      if (response.responseDescription == "Success") {
//         {
// flutter: ║         amount: "10000.00",
// flutter: ║         paymentReference: "b4QaA8Sd2Cmw5ph69CQrINeT5x90aZ0k",
// flutter: ║         transactionDate: "03/02/2024 13:42",
// flutter: ║         fees: 150,
// flutter: ║         channel: "ACCOUNT",
// flutter: ║         responseCode: "02",
// flutter: ║         responseDescription: "Transaction is Pending"
// flutter: ║    }



        // setState(() {
        //   _account = BankAccount(Bank(response!.accountNumber, 0), response.accountNumber, response.accountName);
        //   _isAccountGenerated = true;
        // });
        // Success path intentionally left for integration specifics.
      } else {
        print('[BankCheckout] getTransactionStatus returned non-success. responseCode=${response.responseCode}, responseDescription=${response.responseDescription}, status=${response.status}, rawResponse=${response.rawResponse}');
        setState(() {
          error = response?.responseDescription ?? response?.message ?? 'Unable to confirm bank transfer status. Please try again.';
        });
      }
    } on CustomException catch (e) {
      setState(() {
        error = e.message;
      });
      print('[BankCheckout] CustomException in confirmPayment: ${e.message}');
    } catch (e) {
      print('[BankCheckout] Unexpected error in confirmPayment: $e');
    }

    setState(() {
      _loading = false;
      print('[BankCheckout] confirmPayment finished. loading set to false.');
    });
  }

  void _rebuild() {
    setState(() {
      // Rebuild in order to animate views.
    });
  }
}

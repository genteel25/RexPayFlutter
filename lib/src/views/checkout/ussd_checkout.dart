import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:rexpay/rexpay.dart';
import 'package:rexpay/src/core/api/model/transaction_api_response.dart';
import 'package:rexpay/src/core/api/request/ussd_request_body.dart';
import 'package:rexpay/src/core/api/service/bank_service.dart';
import 'package:rexpay/src/core/api/service/contracts/banks_service_contract.dart';
import 'package:rexpay/src/core/api/service/contracts/ussd_services_contract.dart';
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

class USSDCheckout extends StatefulWidget {
  final Charge charge;
  final OnResponse<CheckoutResponse> onResponse;
  final ValueChanged<bool> onProcessingChange;
  final USSDServiceContract service;
  final AuthKeys authKeys;

  USSDCheckout({
    required this.charge,
    required this.onResponse,
    required this.onProcessingChange,
    required this.service,
    required this.authKeys,
  });

  @override
  _USSDCheckoutState createState() => _USSDCheckoutState(onResponse);
}

class _USSDCheckoutState extends BaseCheckoutMethodState<USSDCheckout> {
  var _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _animation;
  var _autoValidate = AutovalidateMode.disabled;
  late Future<List<Bank>?>? _futureBanks;
  late USSDChargeRequestBody _ussdChargeRequestBody;
  bool _isLoadingUSSDDetails = false;
  bool _isUSSDGenerated = false;
  Bank? _currentBank;
  String _ussdCode = "";
  var _loading = false;
  String error = "";
  List<Bank> banks = [
    Bank("ACCESS BANK", 0, "044", "Access Bank"),
    Bank("ECOBANK NIGERIA", 0, "050", "Ecobank"),
    Bank("FIDELITY BANK", 0, "070", "Fidelity Bank"),
    Bank("FIRST BANK OF NIGERIA", 0, "011", "First Bank"),
    Bank("FIRST CITY MONUMENT BANK", 0, "214", "FCMB"),
    Bank("GUARANTY TRUST BANK", 0, "058", "GTBank"),
    Bank("KEYSTONE BANK", 0, "082", "Keystone Bank"),
    Bank("Rubies (Highstreet)", 0, "7797", "Rubies Bank"),
    Bank("STANBIC IBTC BANK", 0, "221", "Stanbic IBTC"),
    Bank("STERLING BANK", 0, "232", "Sterling Bank"),
    Bank("UNITED BANK FOR AFRICA", 0, "033", "UBA"),
    Bank("UNITY BANK", 0, "215", "Unity Bank"),
    Bank("VFD", 0, "322", "VFD"),
    Bank("WEMA BANK", 0, "035", "Wema Bank"),
    Bank("ZENITH BANK", 0, "057", "Zenith Bank"),
  ];

  _USSDCheckoutState(OnResponse<CheckoutResponse> onResponse) : super(onResponse, CheckoutMethod.bank);

  @override
  void initState() {
    _ussdChargeRequestBody = USSDChargeRequestBody(widget.charge);
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
    return _initialUI();
  }

  Widget _initialUI() {
    return Container(
      child: Form(
        autovalidateMode: _autoValidate,
        key: _formKey,
        child: Column(
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
              'Please choose a bank to continue with payment.',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
            ),
            const SizedBox(
              height: 20.0,
            ),
            DropdownButtonHideUnderline(
                child: InputDecorator(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                enabledBorder: const OutlineInputBorder(borderSide: const BorderSide(color: Colors.grey, width: 0.5)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: context.colorScheme().secondary, width: 1.0)),
                hintText: 'Tap here to choose',
              ),
              isEmpty: _currentBank == null,
              child: DropdownButton<Bank>(
                value: _currentBank,
                isDense: true,
                onChanged: (Bank? newValue) {
                  setState(() {
                    _currentBank = newValue;
                    _ussdChargeRequestBody.setBank(newValue);
                    _controller.forward();
                  });

                  _getUSSDDetails();
                },
                items: banks.map((Bank value) {
                  return DropdownMenuItem<Bank>(
                    value: value,
                    child: Text(value.name!),
                  );
                }).toList(),
              ),
            )),
            if (_isLoadingUSSDDetails == true)
              const Padding(
                padding: EdgeInsets.all(50.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryColor),
                ),
              ),
            if (_isUSSDGenerated == true && _ussdCode != "")
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                padding: const EdgeInsets.all(20),
                color: AppColors.grey,
                child: Center(
                  child: Text(
                    _ussdCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
            const SizedBox(
              height: 30.0,
            ),
            if (_isUSSDGenerated == true)
              AccentButton(
                onPressed: confirmPayment,
                showProgress: _loading,
                text: 'Check Transaction Status',
                color: AppColors.primaryColor,
              )
          ],
        ),
      ),
    );
  }

  void _getUSSDDetails() async {
    if (_isLoadingUSSDDetails) {
      return;
    }

    TransactionApiResponse? response;
    try {
      setState(() {
        _isLoadingUSSDDetails = true;
        _isUSSDGenerated = false;
        error = "";
      });

      print('[USSDCheckout] Starting createPayment for USSD. reference=${widget.charge.reference}, amount=${widget.charge.amount}, bank=${_currentBank?.name}');
      response = await widget.service.createPayment(_ussdChargeRequestBody, widget.authKeys);

      if (response.status == "CREATED") {
        print('[USSDCheckout] createPayment succeeded. status=${response.status}, reference=${response.reference}, paymentUrlReference=${response.paymentUrlReference}');
        _ussdChargeRequestBody.setPaymentUrlReference(response.paymentUrlReference ?? widget.charge.reference ?? "");
        response = await widget.service.chargeUSSD(_ussdChargeRequestBody, widget.authKeys);

        if (response.status == "ONGOING") {
          print('[USSDCheckout] chargeUSSD succeeded with ONGOING status. providerResponse=${response.providerResponse}');
          setState(() {
            _ussdCode = response?.providerResponse ?? "";
            _isUSSDGenerated = true;
          });
          widget.onProcessingChange(true);
        } else {
          print('[USSDCheckout] chargeUSSD returned unexpected status=${response.status}, rawResponse=${response.rawResponse}');
          setState(() {
            error = response?.message ?? 'Unable to generate USSD code. Please try again.';
          });
        }
      } else if (response.status == "ONGOING") {
        print('[USSDCheckout] createPayment returned ONGOING status. providerResponse=${response.providerResponse}');
        setState(() {
          _ussdCode = response?.providerResponse ?? "";
          _isUSSDGenerated = true;
        });
        widget.onProcessingChange(true);
      } else {
        print('[USSDCheckout] createPayment returned unexpected status=${response.status}, rawResponse=${response.rawResponse}');
        setState(() {
          error = response?.message ?? 'Unable to initiate USSD payment. Please try again.';
        });
      }
    } on CustomException catch (e) {
      print(e.message);
      setState(() {
        error = e.message;
      });
    } catch (e) {
      print('[USSDCheckout] Unexpected error in _getUSSDDetails: $e');
    }

    setState(() {
      _isLoadingUSSDDetails = false;
      print('[USSDCheckout] _getUSSDDetails finished. isLoadingUSSDDetails set to false.');
    });
  }

  void _rebuild() {
    setState(() {
      // Rebuild in order to animate views.
    });
  }

  void confirmPayment() async {
    TransactionApiResponse? response;
    try {
      setState(() {
        _loading = true;
        error = "";
      });

      print('[USSDCheckout] confirmPayment tapped. reference=${widget.charge.reference}');
      response = await widget.service.getPaymantDetails(widget.charge.reference!, widget.authKeys);
      // print("response.rawResponse");
      // print(response.rawResponse);
      if (response.responseCode == "02") {
        print('[USSDCheckout] getPaymantDetails returned pending status. responseCode=${response.responseCode}, description=${response.responseDescription}, rawResponse=${response.rawResponse}');
        setState(() {
          error = response?.responseDescription ?? response?.message ?? "";
        });
      } else if (response.responseCode == "00") {
        print('[USSDCheckout] getPaymantDetails returned success. responseCode=${response.responseCode}, description=${response.responseDescription}');
        widget.onResponse(CheckoutResponse(
          message: response.message ?? "",
          reference: response.reference,
          status: response.status ?? "",
          serverResponse: response.rawResponse ?? {},
          method: CheckoutMethod.USSD,
        ));
      } else {
        print('[USSDCheckout] getPaymantDetails returned non-success. responseCode=${response.responseCode}, description=${response.responseDescription}, status=${response.status}, rawResponse=${response.rawResponse}');
        setState(() {
          error = response?.responseDescription ?? response?.message ?? 'Unable to confirm USSD payment status. Please try again.';
        });
      }
    } on CustomException catch (e) {
      print(e);
      setState(() {
        error = e.message;
      });
    } catch (e) {
      print('[USSDCheckout] Unexpected error in confirmPayment: $e');
    }

    setState(() {
      _loading = false;
      print('[USSDCheckout] confirmPayment finished. loading set to false.');
    });
  }
}

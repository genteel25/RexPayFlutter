import 'package:flutter/material.dart';
import 'package:rexpay/rexpay.dart';
import 'package:rexpay/src/core/api/model/transaction_api_response.dart';
import 'package:rexpay/src/core/api/request/card_request_body.dart';
import 'package:rexpay/src/core/api/service/contracts/cards_service_contract.dart';
import 'package:rexpay/src/core/api/service/custom_exception.dart';
import 'package:rexpay/src/core/common/exceptions.dart';
import 'package:rexpay/src/core/common/my_strings.dart';
import 'package:rexpay/src/core/common/rexpay.dart';
import 'package:rexpay/src/core/common/utils.dart';
import 'package:rexpay/src/core/constants/colors.dart';
import 'package:rexpay/src/models/card.dart';
import 'package:rexpay/src/models/charge.dart';
import 'package:rexpay/src/models/checkout_response.dart';
import 'package:rexpay/src/transaction/card_transaction_manager.dart';
import 'package:rexpay/src/views/buttons.dart';
import 'package:rexpay/src/views/checkout/base_checkout.dart';
import 'package:rexpay/src/views/checkout/checkout_widget.dart';
import 'package:rexpay/src/views/input/card_input.dart';
import 'package:rexpay/src/views/input/otp_field.dart';

class CardCheckout extends StatefulWidget {
  final Charge charge;
  final OnResponse<CheckoutResponse> onResponse;
  final ValueChanged<bool> onProcessingChange;
  final ValueChanged<PaymentCard?> onCardChange;
  final bool hideAmount;
  final CardServiceContract service;
  final AuthKeys authKeys;

  CardCheckout({
    Key? key,
    required this.charge,
    required this.onResponse,
    required this.onProcessingChange,
    required this.onCardChange,
    required this.service,
    required this.authKeys,
    this.hideAmount = false,
  }) : super(key: key);

  @override
  _CardCheckoutState createState() => _CardCheckoutState(charge, onResponse);
}

class _CardCheckoutState extends BaseCheckoutMethodState<CardCheckout> {
  final Charge _charge;
  CardRequestBody? _cardRequestBody;
  bool _isInitiating = false;
  bool _isSubmittingOtp = false;
  bool _isOtpUI = false;
  String error = "";
  var _formKey = GlobalKey<FormState>();
  var _autoValidate = AutovalidateMode.disabled;
  TransactionApiResponse? chargeCardResponse;
  TextEditingController otpController = TextEditingController();

  _CardCheckoutState(this._charge, OnResponse<CheckoutResponse> onResponse) : super(onResponse, CheckoutMethod.card);

  @override
  Widget buildAnimatedChild() {
    if (_isOtpUI) return _getOTPUI();

    return _getCardUI();
  }

  Widget _getCardUI() {
    var amountText = _charge.amount.isNegative ? '' : Utils.formatAmount(_charge.amount);

    return Container(
      alignment: Alignment.center,
      child: Column(
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
            Strings.cardInputInstruction,
            key: Key("InstructionKey"),
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(
            height: 20.0,
          ),
          CardInput(
            key: const Key("CardInput"),
            buttonText: widget.hideAmount ? "Continue" : 'Pay $amountText',
            card: _charge.card,
            onValidated: _onCardValidated,
            loading: _isInitiating,
          ),
        ],
      ),
    );
  }

  Widget _getOTPUI() {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidate,
      child: Column(
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
            'We sent an OTP to your device, Please enter the OTP below to confirm transaction',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CardOTPField(
              controller: otpController,
              onSaved: (String? value) {},
            ),
          ),
          const SizedBox(height: 10),
          AccentButton(
            onPressed: confirmPayment,
            showProgress: _isSubmittingOtp,
            text: 'Confirm Payment',
            color: AppColors.primaryColor,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _onCardValidated(PaymentCard? card) {
    if (card == null || _isInitiating) return;
    _charge.card = card;
    widget.onCardChange(_charge.card);
    widget.onProcessingChange(true);

    if (_charge.reference != null && _charge.reference!.isNotEmpty) {
      _chargeCard(_charge);
    } else {
      // This should never happen. Validation has already been done in [RexPayPlugin .checkout]
      throw ChargeException(Strings.noReference);
    }
  }

  void confirmPayment() async {
    print('[CardCheckout] confirmPayment tapped. isSubmittingOtp=$_isSubmittingOtp, otpLength=${otpController.text.length}');

    if (_formKey.currentState?.validate() == false) {
      print('[CardCheckout] OTP validation failed. Current otpLength=${otpController.text.length}');
      return;
    }
    try {
      TransactionApiResponse? res;
      setState(() {
        _isSubmittingOtp = true;
        error = "";
      });
      _cardRequestBody?.otp = otpController.text;
      print('[CardCheckout] OTP set on request body. ref=${widget.charge.reference}, paymentId=${_cardRequestBody?.paymentId}, otpLength=${otpController.text.length}');
      print('[CardCheckout] Calling authorizeCharge for card OTP confirmation...');
      res = await widget.service.authorizeCharge(_cardRequestBody, widget.authKeys);

      if (res.responseCode == "00") {
        print('[CardCheckout] authorizeCharge succeeded. responseCode=${res.responseCode}, paymentId=${res.paymentId}, rawKeys=${res.rawResponse?.keys.toList()}');
        onResponse(
          CheckoutResponse(
            message: "Payment Successful",
            reference: widget.charge.reference,
            status: "SUCCESS",
            method: CheckoutMethod.card,
            serverResponse: res.rawResponse ?? {},
          ),
        );
      } else {
        print('[CardCheckout] authorizeCharge returned non-success responseCode=${res.responseCode}, paymentId=${res.paymentId}, rawResponse=${res.rawResponse}');
      }
    } on CustomException catch (e) {
      setState(() {
        error = e.message;
      });
      print('[CardCheckout] CustomException in confirmPayment: ${e.message}');
    } catch (e) {
      print('[CardCheckout] Unexpected error in confirmPayment: $e');
    }

    setState(() {
      _isSubmittingOtp = false;
      print('[CardCheckout] confirmPayment finished. isSubmittingOtp set to false.');
    });
  }

  void _chargeCard(Charge charge) async {
    try {
      TransactionApiResponse? res;
      print('[CardCheckout] _chargeCard started. amount=${charge.amount}, reference=${charge.reference}, hasCard=${charge.card != null}');
      setState(() {
        _isInitiating = true;
        error = "";
      });

      _cardRequestBody = CardRequestBody(charge, widget.authKeys);

      res = await widget.service.insertPublicKey(widget.authKeys);

      if (res.status == "UPLOADED") {
        print('[CardCheckout] insertPublicKey succeeded with status=${res.status}');
        res = await widget.service.createPayment(_cardRequestBody, widget.authKeys);

        if (res.status == "CREATED" || res.status == "ONGOING") {
          print('[CardCheckout] createPayment succeeded with status=${res.status}, reference=${res.reference}, clientId=${res.clientId}');
          chargeCardResponse = await widget.service.chargeCard(_cardRequestBody, widget.authKeys);

          if (chargeCardResponse?.responseCode == "T0") {
            _cardRequestBody?.paymentId = chargeCardResponse?.paymentId ?? "";
            widget.onProcessingChange(true);
            setState(() {
              _isOtpUI = true;
            });
            print('[CardCheckout] chargeCard returned T0. paymentId=${chargeCardResponse?.paymentId}, responseDescription=${chargeCardResponse?.responseDescription}. Switched to OTP UI.');
          } else {
            print('[CardCheckout] chargeCard returned non-T0 responseCode=${chargeCardResponse?.responseCode}, description=${chargeCardResponse?.responseDescription}, rawResponse=${chargeCardResponse?.rawResponse}');
          }
        } else {
          print('[CardCheckout] createPayment returned unexpected status=${res.status}, rawResponse=${res.rawResponse}');
        }
      } else {
        print('[CardCheckout] insertPublicKey returned unexpected status=${res.status}');
      }
    } on CustomException catch (e) {
      setState(() {
        error = e.message;
      });
      print('[CardCheckout] CustomException in _chargeCard: ${e.message}');
    } catch (e) {
      print('[CardCheckout] Unexpected error in _chargeCard: $e');
    }

    setState(() {
      _isInitiating = false;
      print('[CardCheckout] _chargeCard finished. isInitiating set to false.');
    });
  }
}

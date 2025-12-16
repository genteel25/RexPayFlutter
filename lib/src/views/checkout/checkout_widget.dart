import 'dart:math';

import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:rexpay/rexpay.dart';
import 'package:rexpay/src/core/api/service/contracts/banks_service_contract.dart';
import 'package:rexpay/src/core/api/service/contracts/cards_service_contract.dart';
import 'package:rexpay/src/core/api/service/contracts/ussd_services_contract.dart';
import 'package:rexpay/src/core/common/rexpay.dart';
import 'package:rexpay/src/core/common/utils.dart';
import 'package:rexpay/src/core/constants/colors.dart';
import 'package:rexpay/src/models/card.dart';
import 'package:rexpay/src/models/charge.dart';
import 'package:rexpay/src/models/checkout_response.dart';
import 'package:rexpay/src/views/base_widget.dart';
import 'package:rexpay/src/views/checkout/bank_checkout.dart';
import 'package:rexpay/src/views/checkout/card_checkout.dart';
import 'package:rexpay/src/views/checkout/checkout_method.dart';
import 'package:rexpay/src/views/checkout/landing.dart';
import 'package:rexpay/src/views/checkout/ussd_checkout.dart';
import 'package:rexpay/src/views/common/extensions.dart';
import 'package:rexpay/src/views/custom_dialog.dart';
import 'package:rexpay/src/views/error_widget.dart';
import 'package:rexpay/src/views/sucessful_widget.dart';

const kFullTabHeight = 74.0;

class CheckoutWidget extends StatefulWidget {
  final CheckoutMethod method;
  final Charge charge;
  final bool fullscreen;
  final Widget? logo;
  final bool hideEmail;
  final bool hideAmount;
  final BankServiceContract bankService;
  final CardServiceContract cardsService;
  final USSDServiceContract ussdSService;
  final AuthKeys authKeys;

  CheckoutWidget({
    required this.method,
    required this.charge,
    required this.bankService,
    required this.cardsService,
    required this.ussdSService,
    required this.authKeys,
    this.fullscreen = false,
    this.logo,
    this.hideEmail = false,
    this.hideAmount = false,
  });

  @override
  _CheckoutWidgetState createState() => _CheckoutWidgetState(charge);
}

class _CheckoutWidgetState extends BaseState<CheckoutWidget>
    with TickerProviderStateMixin {
  static const tabBorderRadius = BorderRadius.all(Radius.circular(4.0));
  final Charge _charge;
  int? _currentIndex = 0;
  var _showTabs = true;
  bool _processing = false;
  String? _paymentError;
  bool _paymentSuccessful = false;
  TabController? _tabController;
  late List<MethodItem> _methodWidgets;
  double _tabHeight = kFullTabHeight;
  late AnimationController _animationController;
  CheckoutResponse? _response;
  CheckoutMethod? _selectedCheckout;

  _CheckoutWidgetState(this._charge);

  @override
  void initState() {
    super.initState();
    _init();
    _initPaymentMethods();
    _currentIndex = _getCurrentTab();
    _showTabs = widget.method == CheckoutMethod.selectable ? true : false;
    _tabController = TabController(
        vsync: this,
        length: _methodWidgets.length,
        initialIndex: _currentIndex!);
    _tabController!.addListener(_indexChange);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    if (_charge.card == null) {
      _charge.card = PaymentCard.empty();
    }
  }

  @override
  void dispose() {
    _tabController!.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget buildChild(BuildContext context) {
    var securedWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 3),
              child: Text(
                "Powered by:",
                key: Key("SecuredBy"),
                style: TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/accelerex.png',
              key: const Key("RexPayLogo"),
              package: 'rexpay',
              height: 15,
            )
          ],
        ),
      ],
    );
    return CustomAlertDialog(
      expanded: true,
      fullscreen: widget.fullscreen,
      titlePadding: const EdgeInsets.all(0.0),
      onCancelPress: onCancelPress,
      title: _buildTitle(),
      content: Container(
        child: SingleChildScrollView(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 10.0),
                child: Column(
                  children: <Widget>[
                    if (_selectedCheckout == null && _showTabs)
                      CheckoutLanding(
                        selectCheckoutMethod: _selectCheckoutMethod,
                      ),
                    if (_selectedCheckout != null || _showTabs == false)
                      _showProcessingError()
                          ? _buildErrorWidget()
                          : _paymentSuccessful
                              ? _buildSuccessfulWidget()
                              : _methodWidgets[_currentIndex!].child,
                    const SizedBox(height: 20),
                    securedWidget
                  ],
                )),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final accentColor = context.colorScheme().secondary;
    var emailAndAmount = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (!widget.hideEmail && _charge.email != null)
          Text(
            _charge.email!,
            key: const Key("ChargeEmail"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: context.textTheme().bodySmall?.color, fontSize: 12.0),
          ),
        if (!widget.hideAmount && !_charge.amount.isNegative)
          Row(
            key: const Key("DisplayAmount"),
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Pay',
                style: TextStyle(
                    fontSize: 14.0,
                    color: context.textTheme().displayLarge?.color),
              ),
              const SizedBox(
                width: 5.0,
              ),
              Flexible(
                  child: Text(Utils.formatAmount(_charge.amount),
                      style: TextStyle(
                          fontSize: 15.0,
                          color: context.textTheme().displaySmall?.color,
                          fontWeight: FontWeight.bold)))
            ],
          )
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_showTabs && _selectedCheckout != null)
          buildCheckoutMethods(accentColor),
        Container(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.logo == null)
                Image.asset(
                  'assets/images/rexpay.png',
                  key: const Key("RexPayIcon"),
                  package: 'rexpay',
                  width: 70,
                  height: 30,
                )
              else
                SizedBox(
                  key: const Key("Logo"),
                  child: widget.logo,
                ),
              const SizedBox(
                width: 50,
              ),
              Expanded(child: emailAndAmount),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCheckoutMethods(Color accentColor) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      child: Container(
        color: context.colorScheme().background.withOpacity(0.5),
        height: _tabHeight,
        alignment: Alignment.center,
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          unselectedLabelColor: context.colorScheme().onBackground,
          labelColor: accentColor,
          indicatorColor:
              (!_processing) ? AppColors.primaryColor : Colors.transparent,
          onTap: (int index) {
            if (_processing) {
              return;
            }
            _tabController?.index = index;
          },
          labelStyle:
              const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
          tabs: _methodWidgets.map<Tab>((MethodItem m) {
            return Tab(
              text: m.text,
              icon: m.icon,
              iconMargin: const EdgeInsets.only(bottom: 10),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _indexChange() {
    if (!_processing) {
      setState(() {
        _currentIndex = _tabController!.index;
        // Update the checkout here just in case the user terminates the transaction
        // forcefully by tapping the close icon
      });
    }
  }

  void _initPaymentMethods() {
    _methodWidgets = [
      MethodItem(
        text: 'Card',
        icon: Image.asset(
          "assets/images/credit-card-payment.png",
          key: const Key("card"),
          package: 'rexpay',
          width: 24.0,
        ),
        child: CardCheckout(
          key: const Key("CardCheckout"),
          authKeys: widget.authKeys,
          service: widget.cardsService,
          charge: _charge,
          onProcessingChange: _onProcessingChange,
          onResponse: _onPaymentResponse,
          hideAmount: widget.hideAmount,
          onCardChange: (PaymentCard? card) {
            if (card == null) return;
            _charge.card!.number = card.number;
            _charge.card!.cvc = card.cvc;
            _charge.card!.expiryMonth = card.expiryMonth;
            _charge.card!.expiryYear = card.expiryYear;
          },
        ),
      ),
      MethodItem(
        text: 'Bank Transfer',
        icon: Image.asset(
          "assets/images/bank.png",
          key: const Key("bank"),
          package: 'rexpay',
          width: 24.0,
        ),
        child: BankCheckout(
          authKeys: widget.authKeys,
          charge: _charge,
          service: widget.bankService,
          onResponse: _onPaymentResponse,
          onProcessingChange: _onProcessingChange,
        ),
      ),
      MethodItem(
        text: 'USSD',
        icon: Image.asset(
          "assets/images/ussd.png",
          key: const Key("ussd"),
          package: 'rexpay',
          width: 24.0,
        ),
        child: USSDCheckout(
          authKeys: widget.authKeys,
          charge: _charge,
          service: widget.ussdSService,
          onResponse: _onPaymentResponse,
          onProcessingChange: _onProcessingChange,
        ),
      )
    ];
  }

  void _onProcessingChange(bool processing) {
    setState(() {
      _processing = processing;
    });
  }

  void _selectCheckoutMethod(CheckoutMethod method) {
    setState(() {
      _currentIndex = _setCurrentTab(method);
      _selectedCheckout = method;
    });

    _tabController?.animateTo(_setCurrentTab(method)!);
  }

  _showProcessingError() {
    return !(_paymentError == null || _paymentError!.isEmpty);
  }

  void _onPaymentResponse(CheckoutResponse response) {
    // log("Pro")
    _response = response;
    if (!mounted) return;
    if (response.status == "SUCCESS") {
      _onPaymentSuccess();
    } else {
      _onPaymentError(response.message);
    }
  }

  void _onPaymentSuccess() {
    setState(() {
      _paymentSuccessful = true;
      _paymentError = null;
      _onProcessingChange(false);
    });
  }

  void _onPaymentError(String? value) {
    setState(() {
      _paymentError = value;
      _paymentSuccessful = false;
      _onProcessingChange(false);
    });
  }

  int? _getCurrentTab() {
    int? checkedTab;
    switch (widget.method) {
      case CheckoutMethod.selectable:
      case CheckoutMethod.card:
        checkedTab = 0;
        break;
      case CheckoutMethod.bank:
        checkedTab = 1;
      case CheckoutMethod.USSD:
        checkedTab = 2;
        break;
    }
    return checkedTab;
  }

  int? _setCurrentTab(CheckoutMethod method) {
    int? checkedTab = 0;
    switch (method) {
      case CheckoutMethod.selectable:
      case CheckoutMethod.card:
        checkedTab = 0;
        break;
      case CheckoutMethod.bank:
        checkedTab = 1;
      case CheckoutMethod.USSD:
        checkedTab = 2;
        break;
    }
    return checkedTab;
  }

  Widget _buildSuccessfulWidget() => SuccessfulWidget(
        amount: _charge.amount,
        onCountdownComplete: () {
          Navigator.of(context).pop(_response);
        },
      );

  Widget _buildErrorWidget() => ErrorWidget(
        message: _paymentError ?? "Payment error",
        onCountdownComplete: () {
          Navigator.of(context).pop(_response);
        },
      );

  @override
  getPopReturnValue() {
    return _getResponse();
  }

  CheckoutResponse _getResponse() {
    CheckoutResponse? response = _response;
    if (response == null) {
      response = CheckoutResponse.defaults();
      response.method = _tabController!.index == 0
          ? CheckoutMethod.card
          : CheckoutMethod.bank;
    }
    return response;
  }

  _init() {
    Utils.setCurrencyFormatter(_charge.currency, _charge.locale);
  }
}

typedef void OnResponse<CheckoutResponse>(CheckoutResponse response);

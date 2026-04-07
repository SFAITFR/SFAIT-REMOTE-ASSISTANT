import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/common/widgets/toolbar.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void _showSuccess() {
  showToast(translate("Successful"));
}

void setTemporaryPasswordLengthDialog(
    OverlayDialogManager dialogManager) async {
  List<String> lengths = ['6', '8', '10'];
  String length = await bind.mainGetOption(key: "temporary-password-length");
  var index = lengths.indexOf(length);
  if (index < 0) index = 0;
  length = lengths[index];
  dialogManager.show((setState, close, context) {
    setLength(newValue) {
      final oldValue = length;
      if (oldValue == newValue) return;
      setState(() {
        length = newValue;
      });
      bind.mainSetOption(key: "temporary-password-length", value: newValue);
      bind.mainUpdateTemporaryPassword();
      Future.delayed(Duration(milliseconds: 200), () {
        close();
        _showSuccess();
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Set one-time password length")),
      content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: lengths
              .map(
                (value) => Row(
                  children: [
                    Text(value),
                    Radio(
                        value: value, groupValue: length, onChanged: setLength),
                  ],
                ),
              )
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showServerSettings(OverlayDialogManager dialogManager,
    void Function(VoidCallback) setState) async {
  Map<String, dynamic> options = {};
  try {
    options = jsonDecode(await bind.mainGetOptions());
  } catch (e) {
    print("Invalid server config: $e");
  }
  for (final key in [
    'custom-rendezvous-server',
    'relay-server',
    'api-server',
    'key',
  ]) {
    final value = options[key];
    if (value == null || value.toString().trim().isEmpty) {
      final hardValue = bind.mainGetHardOption(key: key);
      if (hardValue.trim().isNotEmpty) {
        options[key] = hardValue;
      }
    }
  }
  showServerSettingsWithValue(
      ServerConfig.fromOptions(options), dialogManager, setState);
}

void showServerSettingsWithValue(
    ServerConfig serverConfig,
    OverlayDialogManager dialogManager,
    void Function(VoidCallback)? upSetState) async {
  final idCtrl = TextEditingController(text: serverConfig.idServer);
  final relayCtrl = TextEditingController(text: serverConfig.relayServer);
  final apiCtrl = TextEditingController(text: serverConfig.apiServer);
  final keyCtrl = TextEditingController(text: serverConfig.key);

  dialogManager.show((setState, close, context) {
    Widget buildField(String label, TextEditingController controller,
        {bool autofocus = false}) {
      if (isDesktop || isWeb) {
        return Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                enabled: false,
                readOnly: true,
                decoration: InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                autofocus: autofocus,
              ).workaroundFreezeLinuxMint(),
            ),
          ],
        );
      }

      return TextFormField(
        controller: controller,
        enabled: false,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
        ),
      ).workaroundFreezeLinuxMint();
    }

    return CustomAlertDialog(
      title: Text(translate('ID/Relay Server')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Form(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildField(translate('ID Server'), idCtrl, autofocus: true),
              SizedBox(height: 8),
              if (!isIOS && !isWeb) ...[
                buildField(translate('Relay Server'), relayCtrl),
                SizedBox(height: 8),
              ],
              buildField(translate('API Server'), apiCtrl),
              SizedBox(height: 8),
              buildField('Key', keyCtrl),
            ],
          ),
        ),
      ),
      actions: [
        dialogButton('Close', onPressed: () {
          close();
        }, isOutline: true),
      ],
    );
  });
}

void setPrivacyModeDialog(
  OverlayDialogManager dialogManager,
  List<TToggleMenu> privacyModeList,
  RxString privacyModeState,
) async {
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('Privacy mode')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: privacyModeList
              .map((value) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: value.child,
                    value: value.value,
                    onChanged: value.onChanged,
                  ))
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

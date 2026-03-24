import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter/material.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // runApp 실행 이전이면 필요

  await FlutterNaverMap().init(
    clientId: '0dz77rdfgy',
    onAuthFailed: (ex) {
      switch (ex) {
        case NQuotaExceededException(:final message):
          print("사용량 초과 (message: $message)");
          break;
        case NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException():
          print("인증 실패: $ex");
          break;
      }
    },
  );

  runApp(const ProviderScope(child: RunApp()));
}

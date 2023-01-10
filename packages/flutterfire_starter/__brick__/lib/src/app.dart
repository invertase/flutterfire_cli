{{#analyticswithnavigator}}import 'package:firebase_analytics/firebase_analytics.dart';{{/analyticswithnavigator}}
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

{{#analyticswithgorouter}}import 'router.dart';{{/analyticswithgorouter}}
{{^analyticswithgorouter}}import 'sample_feature/sample_item_details_view.dart';
import 'sample_feature/sample_item_list_view.dart';
{{/analyticswithgorouter}}


class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    {{#analyticswithgorouter}}{{> analytics_go_router.dart }}{{/analyticswithgorouter}}{{^analyticswithgorouter}}{{> analytics_navigator.dart }}{{/analyticswithgorouter}}
  }
}

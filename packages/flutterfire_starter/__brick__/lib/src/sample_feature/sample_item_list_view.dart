import 'package:flutter/material.dart';
{{#analyticswithgorouter}}import 'package:go_router/go_router.dart';{{/analyticswithgorouter}}

import 'sample_item.dart';
import 'sample_item_details_view.dart';

class SampleItemListView extends StatelessWidget {
  const SampleItemListView({
    Key? key,
    this.items = const [SampleItem(1), SampleItem(2), SampleItem(3)],
  }) : super(key: key);

  static const routeName = '/';

  final List<SampleItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Items'),
      ),
      body: ListView.builder(
        restorationId: 'sampleItemListView',
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) {
          final item = items[index];

          return ListTile(
              title: Text('SampleItem ${item.id}'),
              leading: const CircleAvatar(
                foregroundImage: AssetImage('assets/images/flutter_logo.png'),
              ),
              onTap: () {
                {{#analyticswithgorouter}}
                GoRouter.of(context)
                    .go('/${SampleItemDetailsView.routeName}/${item.id}');
                {{/analyticswithgorouter}}
                {{^analyticswithgorouter}}
                Navigator.restorablePushNamed(
                  context,
                  SampleItemDetailsView.routeName,
                  arguments: item.id,
                );
                {{/analyticswithgorouter}}    
              });
        },
      ),
    );
  }
}

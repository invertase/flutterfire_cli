import 'package:flutter/material.dart';

/// Displays detailed information about a SampleItem.
class SampleItemDetailsView extends StatelessWidget {
  const SampleItemDetailsView({Key? key, this.itemId}) : super(key: key);

  static const routeName = '/sample_item';
  final int? itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item $itemId Details'),
      ),
      body: const Center(
        child: Text('More Information Here'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantCampaignsPage extends StatelessWidget {
  const MerchantCampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.campaigns.title'),
      subtitle: texts.text('merchant.campaigns.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.campaigns.tooltip')),
      child: MerchantEmptyState(
        title: texts.text('merchant.campaigns.emptyTitle'),
        message: texts.text('merchant.campaigns.emptyMessage'),
        actionLabel: texts.text('common.refresh'),
        onAction: () {},
      ),
    );
  }
}

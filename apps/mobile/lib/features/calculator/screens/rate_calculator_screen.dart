import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../config/constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/rates_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';
import '../../../shared/components/pill_selector.dart';
import '../../../shared/components/progress_ring.dart';
import '../../../shared/layout/app_scaffold.dart';

class RateCalculatorScreen extends ConsumerStatefulWidget {
  const RateCalculatorScreen({super.key});

  @override
  ConsumerState<RateCalculatorScreen> createState() => _RateCalculatorScreenState();
}

class _RateCalculatorScreenState extends ConsumerState<RateCalculatorScreen> {
  final _amountController = TextEditingController(text: '100');
  String _selectedAsset = AppConstants.usdt;
  String _selectedFiat = AppConstants.ngn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculate();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount > 0) {
      await ref.read(ratesProvider.notifier).calculateQuote(
        asset: _selectedAsset,
        amount: amount,
        fiat: _selectedFiat,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratesState = ref.watch(ratesProvider);
    final quote = ratesState.activeQuote;
    final remainingSecs = ratesState.quoteSecondsRemaining;
    final totalValidSecs = quote?.validForSeconds ?? 900;
    final progress = totalValidSecs > 0 ? (remainingSecs / totalValidSecs) : 0.0;

    final mins = remainingSecs ~/ 60;
    final secs = remainingSecs % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return AppScaffold(
      currentIndex: 2,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Instant Rate Quote',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Get an exact guaranteed payout calculation for your crypto.',
                style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 20),

              // 1. Currency & Fiat Selectors
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('You Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedSage)),
                        const SizedBox(height: 6),
                        PillSelector<String>(
                          options: const [AppConstants.usdt, AppConstants.usdc, AppConstants.btc],
                          selected: _selectedAsset,
                          labelBuilder: (a) => a,
                          onSelected: (val) {
                            setState(() => _selectedAsset = val);
                            _calculate();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('You Receive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedSage)),
                        const SizedBox(height: 6),
                        PillSelector<String>(
                          options: const [AppConstants.ngn, AppConstants.ghs],
                          selected: _selectedFiat,
                          labelBuilder: (f) => f,
                          onSelected: (val) {
                            setState(() => _selectedFiat = val);
                            _calculate();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Amount Input
              CustomTextField(
                label: 'Crypto Amount ($_selectedAsset)',
                hintText: '100',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.currency_exchange, color: AppColors.deepEmerald, size: 20),
                onChanged: (_) => _calculate(),
              ),
              const SizedBox(height: 20),

              // 3. Quote Result Container with Circular Countdown Ring
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.darkCardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.darkCardBorder),
                ),
                child: Column(
                  children: [
                    if (quote != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NET PAYOUT AMOUNT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.electricMint,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.formatFiat(
                                  double.tryParse(quote.netPayoutFiat) ?? 0.0,
                                  currency: quote.fiat,
                                ),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          // Circular Rate Lock Ring
                          ProgressRing(
                            progress: progress,
                            centerText: timeStr,
                            subText: 'LOCKED',
                            size: 78,
                            strokeWidth: 6,
                            progressColor: AppColors.electricMint,
                            backgroundColor: AppColors.darkCardBorder,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.darkCardBorder),
                      const SizedBox(height: 12),

                      // Rate Breakdown Table
                      _buildQuoteRow('Effective Exchange Rate', '${_selectedFiat == 'NGN' ? '₦' : '₵'}${quote.effectiveRate} / $_selectedAsset'),
                      _buildQuoteRow('Gross Calculation', '${_selectedFiat == 'NGN' ? '₦' : '₵'}${quote.grossFiatAmount}'),
                      _buildQuoteRow('Platform Spread Fee (${quote.spreadPercent})', '-${_selectedFiat == 'NGN' ? '₦' : '₵'}${quote.spreadFeeFiat}'),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Calculating guaranteed quote...',
                          style: TextStyle(color: AppColors.mutedSubtext, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action CTA: Lock Rate & Proceed to Deposit
              CustomButton(
                text: 'Deposit & Lock This Rate',
                icon: Icons.arrow_forward,
                variant: ButtonVariant.primary,
                onPressed: () => context.go('/deposit'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedSubtext)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

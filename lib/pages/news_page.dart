import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  final List<Map<String, dynamic>> _articles = const [
    {
      'title': 'How to Build Your Load-Velocity Profile',
      'source': 'Science for Sport',
      'date': 'Reviewed 2024',
      'excerpt': 'Take submaximal sets at different loads, plot the line of best fit, and extrapolate to your Minimal Velocity Threshold to predict 1RM without ever lifting to failure.',
      'icon': Icons.show_chart,
      'color': Colors.blue,
      'url': 'https://www.scienceforsport.com/velocity-based-training/',
    },
    {
      'title': 'Velocity Loss Thresholds: Managing Fatigue in Real Time',
      'source': 'VBT Coach',
      'date': 'Updated 2024',
      'excerpt': 'Science recommends 20% VL for strength, 30% for muscular endurance, and as low as 10% for speed-power athletes. Your device can terminate the set for you.',
      'icon': Icons.battery_alert,
      'color': Colors.orange,
      'url': 'https://vbtcoach.com/velocity-loss/',
    },
    {
      'title': 'Understanding the Minimal Velocity Threshold',
      'source': 'Athletic Lab',
      'date': '2023',
      'excerpt': 'MVTs are exercise-specific: back squat ≈ 0.30 m/s, bench press ≈ 0.15 m/s. The MVT stays constant whether you do a true 1RM or a set-to-failure at 75%.',
      'icon': Icons.speed,
      'color': Colors.green,
      'url': 'https://athleticlab.com/velocity-based-training-mvt/',
    },
    {
      'title': 'Why VBT Outperforms %1RM Programming',
      'source': 'Sport Smith',
      'date': '2024',
      'excerpt': 'A fixed 80% one week may not equal 80% the next. Velocity tells you what your muscles are actually capable of doing TODAY — and adjusts your load accordingly.',
      'icon': Icons.compare_arrows,
      'color': Colors.red,
      'url': 'https://sportsmith.co/velocity-based-training/',
    },
    {
      'title': 'The Force-Velocity Curve Explained',
      'source': 'Science for Sport',
      'date': 'Reviewed 2024',
      'excerpt': 'As load increases, velocity drops. This fundamental relationship powers every VBT zone calculation. Learn how "absolute strength" differs from "starting strength" on the continuum.',
      'icon': Icons.stacked_line_chart,
      'color': Colors.purple,
      'url': 'https://www.scienceforsport.com/force-velocity-curve/',
    },
  ];

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'VBT Library',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          final article = _articles[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => _launchUrl(article['url'] as String),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (article['color'] as MaterialColor).shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            article['icon'] as IconData,
                            color: (article['color'] as MaterialColor).shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article['source'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (article['color'] as MaterialColor).shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              article['date'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['excerpt'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Read Article',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

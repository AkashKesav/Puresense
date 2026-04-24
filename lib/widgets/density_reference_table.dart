import 'package:flutter/material.dart';

class DensityReferenceTable extends StatelessWidget {
  final String? highlightedLabel;
  const DensityReferenceTable({super.key, this.highlightedLabel});

  final data = const [
    {'metal': 'Platinum', 'range': '21.0 – 21.5'},
    {'metal': 'Gold', 'range': '18.5 – 20.0'},
    {'metal': 'Silver/Lead', 'range': '10.0 – 11.5'},
    {'metal': 'Copper/Brass', 'range': '8.3 – 9.0'},
    {'metal': 'Steel/Iron', 'range': '7.5 – 8.2'},
    {'metal': 'Aluminum', 'range': '2.5 – 2.9'},
    {'metal': 'Floats', 'range': '< 1.0'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Density Reference Table',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          ...data.map((row) {
            final isHighlighted = highlightedLabel != null &&
                row['metal']!.toLowerCase().contains(highlightedLabel!.toLowerCase().split('/').first);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isHighlighted ? const Color(0xFFFFB300).withOpacity(0.15) : null,
                border: isHighlighted
                    ? const Border(
                        left: BorderSide(color: Color(0xFFFFB300), width: 3),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    row['metal']!,
                    style: TextStyle(
                      color: isHighlighted ? const Color(0xFFFFB300) : Colors.white,
                      fontSize: 14,
                      fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    row['range']!,
                    style: TextStyle(
                      color: isHighlighted ? const Color(0xFFFFB300) : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

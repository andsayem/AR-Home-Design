import 'package:flutter/material.dart';

const furnitureCatalog = <String, List<Map<String, String>>>{
  '🛋️ Furniture': [
    {'emoji': '🛋️', 'label': 'Sofa'},
    {'emoji': '🛏️', 'label': 'Bed'},
    {'emoji': '🪑', 'label': 'Chair'},
    {'emoji': '🪞', 'label': 'Mirror'},
    {'emoji': '🚪', 'label': 'Door'},
    {'emoji': '🪟', 'label': 'Window'},
    {'emoji': '🛁', 'label': 'Bathtub'},
    {'emoji': '🚽', 'label': 'Toilet'},
    {'emoji': '🚿', 'label': 'Shower'},
    {'emoji': '🗄️', 'label': 'Cabinet'},
    {'emoji': '🪜', 'label': 'Ladder'},
    {'emoji': '🛒', 'label': 'Cart'},
  ],
  '❄️ Appliances': [
    {'emoji': '❄️', 'label': 'AC'},
    {'emoji': '🌀', 'label': 'Fan'},
    {'emoji': '📺', 'label': 'TV'},
    {'emoji': '💡', 'label': 'Light'},
    {'emoji': '🔌', 'label': 'Socket'},
    {'emoji': '🖥️', 'label': 'Monitor'},
    {'emoji': '🔦', 'label': 'Lamp'},
    {'emoji': '🔆', 'label': 'Ceiling Light'},
    {'emoji': '📱', 'label': 'Phone'},
    {'emoji': '⌨️', 'label': 'Keyboard'},
    {'emoji': '🎵', 'label': 'Speaker'},
    {'emoji': '🍳', 'label': 'Stove'},
  ],
  '🌿 Plants': [
    {'emoji': '🌿', 'label': 'Plant'},
    {'emoji': '🌸', 'label': 'Flower'},
    {'emoji': '🌳', 'label': 'Tree'},
    {'emoji': '🌵', 'label': 'Cactus'},
    {'emoji': '🪴', 'label': 'Potted Plant'},
    {'emoji': '🌺', 'label': 'Hibiscus'},
    {'emoji': '🌻', 'label': 'Sunflower'},
    {'emoji': '🌹', 'label': 'Rose'},
    {'emoji': '🍀', 'label': 'Clover'},
    {'emoji': '🌾', 'label': 'Grass'},
    {'emoji': '🍃', 'label': 'Leaves'},
    {'emoji': '🌲', 'label': 'Pine'},
  ],
  '🖼️ Decor': [
    {'emoji': '🖼️', 'label': 'Picture'},
    {'emoji': '🕰️', 'label': 'Clock'},
    {'emoji': '📚', 'label': 'Bookshelf'},
    {'emoji': '🪔', 'label': 'Lamp'},
    {'emoji': '🎨', 'label': 'Art'},
    {'emoji': '🪆', 'label': 'Decor'},
    {'emoji': '🧸', 'label': 'Toy'},
    {'emoji': '🎭', 'label': 'Mask'},
    {'emoji': '🏺', 'label': 'Vase'},
    {'emoji': '🕯️', 'label': 'Candle'},
    {'emoji': '🎪', 'label': 'Tent'},
    {'emoji': '🛕', 'label': 'Ornament'},
  ],
  '🍽️ Kitchen': [
    {'emoji': '🍽️', 'label': 'Dining'},
    {'emoji': '🥘', 'label': 'Pan'},
    {'emoji': '🫙', 'label': 'Jar'},
    {'emoji': '🍶', 'label': 'Bottle'},
    {'emoji': '🥄', 'label': 'Spoon'},
    {'emoji': '🍴', 'label': 'Fork'},
    {'emoji': '🔪', 'label': 'Knife'},
    {'emoji': '🫖', 'label': 'Kettle'},
    {'emoji': '☕', 'label': 'Coffee'},
    {'emoji': '🍜', 'label': 'Noodles'},
    {'emoji': '🧁', 'label': 'Cupcake'},
    {'emoji': '🍕', 'label': 'Pizza'},
  ],
};

class FurniturePicker extends StatefulWidget {
  final void Function(String emoji, String label, String category) onSelect;

  const FurniturePicker({super.key, required this.onSelect});

  @override
  State<FurniturePicker> createState() => _FurniturePickerState();
}

class _FurniturePickerState extends State<FurniturePicker>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _categories = furnitureCatalog.keys.toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Place Furniture & Objects',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Category tabs
          TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: const Color(0xFF4F8EF7),
            indicatorWeight: 2.5,
            labelColor: const Color(0xFF4F8EF7),
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            tabAlignment: TabAlignment.start,
            tabs: _categories
                .map((c) => Tab(text: c))
                .toList(),
          ),

          const SizedBox(height: 8),

          // Grid views
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: _categories.map((cat) {
                final items = furnitureCatalog[cat]!;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return GestureDetector(
                      onTap: () {
                        widget.onSelect(
                            item['emoji']!, item['label']!, cat);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E3A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item['emoji']!,
                                style: const TextStyle(fontSize: 30)),
                            const SizedBox(height: 4),
                            Text(
                              item['label']!,
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

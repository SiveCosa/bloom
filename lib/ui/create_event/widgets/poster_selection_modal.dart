import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../domain/event/create_event_state.dart';

class PosterSelectionModal extends ConsumerStatefulWidget {
  const PosterSelectionModal({super.key});

  @override
  ConsumerState<PosterSelectionModal> createState() => _PosterSelectionModalState();
}

class _PosterSelectionModalState extends ConsumerState<PosterSelectionModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'Trending';
  
  final List<String> _filters = ['Trending', 'Birthday', 'Game Day', 'Elegant', 'Nightlife'];
  
  // Mocked poster URLs
  final List<String> _mockPosters = List.generate(12, (index) => 'https://picsum.photos/seed/${index + 100}/400/400');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCompressImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final filePath = pickedFile.path;
      final targetPath = '${filePath}_compressed.webp';
      
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: 80,
        format: CompressFormat.webp,
      );

      if (compressedFile != null) {
        // In a real app, upload to Firebase Storage and get URL
        // For now, we'll just use the local path as a mock URL or just select it
        final imageUrl = 'https://picsum.photos/seed/uploaded/400/400'; // Mocked
        _selectPoster(imageUrl);
      }
    }
  }

  Future<void> _selectPoster(String url) async {
    try {
      final imageProvider = NetworkImage(url);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
      ).timeout(const Duration(seconds: 5));
      
      final colors = <Color>[];
      if (paletteGenerator.vibrantColor != null) colors.add(paletteGenerator.vibrantColor!.color);
      if (paletteGenerator.lightVibrantColor != null) colors.add(paletteGenerator.lightVibrantColor!.color);
      if (paletteGenerator.darkVibrantColor != null) colors.add(paletteGenerator.darkVibrantColor!.color);
      if (paletteGenerator.mutedColor != null) colors.add(paletteGenerator.mutedColor!.color);
      if (paletteGenerator.dominantColor != null) colors.add(paletteGenerator.dominantColor!.color);
      
      // Fill to 5 colors if necessary
      if (colors.length < 5) {
        for (var swatch in paletteGenerator.paletteColors) {
          if (!colors.contains(swatch.color)) {
            colors.add(swatch.color);
            if (colors.length >= 5) break;
          }
        }
      }
      
      ref.read(createEventProvider.notifier).updatePosterWithColors(url, colors);
    } catch (e) {
      // Fallback to default colors if extraction fails
      ref.read(createEventProvider.notifier).updatePosterWithColors(url, CreateEventState.defaultAuroraColors);
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Find an image',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white24),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Filters
          SizedBox(
            height: 40,
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.white24 : Colors.white10,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Square'),
              Tab(text: 'Portrait'),
            ],
          ),

          // Grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPosterGrid(1.0),
                _buildPosterGrid(0.75),
              ],
            ),
          ),

          // Bottom Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _pickAndCompressImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80F0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                icon: const Icon(Icons.upload_outlined, color: Colors.white),
                label: const Text(
                  'Upload image',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterGrid(double aspectRatio) {
    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: aspectRatio,
      ),
      itemCount: _mockPosters.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _selectPoster(_mockPosters[index]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(_mockPosters[index]),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}

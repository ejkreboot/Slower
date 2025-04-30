import 'package:flutter/material.dart';
import '../models/saved_regions.dart';

class SavedRegionsPanel extends StatefulWidget {
  final String audioFileName;
  final List<SavedRegion> regions;
  final void Function(SavedRegion) onSelect;
  final void Function(String name) onSave;

  const SavedRegionsPanel({
    super.key,
    required this.audioFileName,
    required this.regions,
    required this.onSelect,
    required this.onSave,
  });

  @override
  State<SavedRegionsPanel> createState() => _SavedRegionsPanelState();
}

class _SavedRegionsPanelState extends State<SavedRegionsPanel> {
  String _typedName = '';

  Future<void> _handleSave() async {
    final name = _typedName.trim();
    if (name.isNotEmpty) {
      widget.onSave(name);
      setState(() {
        _typedName = '';
      });
      await SavedRegion.saveRegions(widget.audioFileName, widget.regions);
    }
  }

  Future<void> _handleDelete(SavedRegion region) async {
    setState(() {
      widget.regions.remove(region);
    });
    await SavedRegion.saveRegions(widget.audioFileName, widget.regions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Name this region...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _typedName = value;
                  });
                },
                onSubmitted: (_) => _handleSave(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.note_add_outlined, size: 28),
              label: const Text(
                "Save",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
              ),
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095F2),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Saved Selections:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.regions.isEmpty
              ? const Text('No saved regions yet.', style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  itemCount: widget.regions.length,
                  itemBuilder: (context, index) {
                    final region = widget.regions[index];
                    return ListTile(
                      title: Text(region.name),
                      leading: const Icon(Icons.music_note),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _handleDelete(region),
                      ),
                      onTap: () => widget.onSelect(region),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

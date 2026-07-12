import 'package:flutter/material.dart';
import '../models/filter_options.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

const Color kPrimaryGreen = Color(0xFF2E8B57);

/// Painel deslizante de baixo para cima com opções de filtragem
/// para POIs e/ou roteiros, consoante os parâmetros recebidos.
class FilterBottomSheet extends StatefulWidget {
  final POIFilter? initialPoiFilter;
  final RoteiroFilter? initialRoteiroFilter;
  final bool showPoiFilters;
  final bool showRoteiroFilters;
  final List<String> availablePoiCategories;
  final List<String> availableRoteiroCategories;
  final Function(POIFilter? poiFilter, RoteiroFilter? roteiroFilter) onApply;

  const FilterBottomSheet({
    super.key,
    this.initialPoiFilter,
    this.initialRoteiroFilter,
    this.showPoiFilters = true,
    this.showRoteiroFilters = false,
    this.availablePoiCategories = const [],
    this.availableRoteiroCategories = const [],
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => FilterBottomSheetState();
}

class FilterBottomSheetState extends State<FilterBottomSheet> {
  late POIFilter _poiFilter;
  late RoteiroFilter _roteiroFilter;
  
  late List<String> _categorias;
  late List<String> _roteiroCategorias;

  @override
  void initState() {
    super.initState();
    _poiFilter = widget.initialPoiFilter ?? POIFilter();
    _roteiroFilter = widget.initialRoteiroFilter ?? RoteiroFilter();

    _categorias = ['Tudo', ...widget.availablePoiCategories];
    _roteiroCategorias = ['Qualquer', ...widget.availableRoteiroCategories];
    
    if (_categorias.length == 1) {
      _categorias = ['Tudo', 'Histórico', 'Natureza', 'Geológico', 'Trilho', 'Gastronomia'];
    }
    if (_roteiroCategorias.length == 1) {
      _roteiroCategorias = ['Qualquer', 'Histórico', 'Natureza', 'Geológico', 'Trilho'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Puxador visual do painel
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.filters, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _poiFilter = POIFilter();
                    _roteiroFilter = RoteiroFilter();
                  });
                },
                child: Text(AppLocalizations.of(context)!.clear, style: TextStyle(color: kPrimaryGreen)),
              ),
            ],
          ),
          SizedBox(height: 10),
          
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showPoiFilters) ...[
                    if (widget.showPoiFilters && widget.showRoteiroFilters)
                      Text(AppLocalizations.of(context)!.locationsPois, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(height: 10),
                    _buildPoiFilters(),
                    SizedBox(height: 20),
                  ],
                  if (widget.showRoteiroFilters) ...[
                    if (widget.showPoiFilters && widget.showRoteiroFilters)
                      Text(AppLocalizations.of(context)!.tabItineraries, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(height: 10),
                    _buildRoteiroFilters(),
                  ],
                ],
              ),
            ),
          ),
          
          SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              widget.onApply(
                widget.showPoiFilters ? _poiFilter : null, 
                widget.showRoteiroFilters ? _roteiroFilter : null
              );
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.applyFilters, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.category, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categorias.map((cat) {
            bool isSelected = _poiFilter.categoria == cat;
            return ChoiceChip(
              label: Text(_getCategoryTranslation(context, cat)),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: kPrimaryGreen.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: isSelected ? kPrimaryGreen : Colors.black87),
              onSelected: (selected) {
                if (selected) setState(() => _poiFilter = _poiFilter.copyWith(categoria: cat));
              },
            );
          }).toList(),
        ),
        SizedBox(height: 20),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.onlyWith360),
          value: _poiFilter.tem360,
          activeThumbColor: kPrimaryGreen,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _poiFilter = _poiFilter.copyWith(tem360: val)),
        ),
      ],
    );
  }

  Widget _buildRoteiroFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _roteiroCategorias.map((cat) {
            bool isSelected = _roteiroFilter.categoria == cat;
            return ChoiceChip(
              label: Text(cat == 'Qualquer' ? AppLocalizations.of(context)!.difAny : _getCategoryTranslation(context, cat)),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: kPrimaryGreen.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: isSelected ? kPrimaryGreen : Colors.black87),
              onSelected: (selected) {
                if (selected) setState(() => _roteiroFilter = _roteiroFilter.copyWith(categoria: cat));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Devolve a tradução localizada do nome da categoria, usando AppLocalizations.
  String _getCategoryTranslation(BuildContext context, String category) {
    switch (category) {
      case 'Tudo':
        return AppLocalizations.of(context)!.catAll;
      case 'Histórico':
        return AppLocalizations.of(context)!.catHistoric;
      case 'Natureza':
        return AppLocalizations.of(context)!.catNature;
      case 'Geológico':
        return AppLocalizations.of(context)!.catGeologic;
      case 'Trilho':
        return AppLocalizations.of(context)!.catTrail;
      case 'Gastronomia':
        return AppLocalizations.of(context)!.catGastronomy;
      default:
        return category;
    }
  }

}

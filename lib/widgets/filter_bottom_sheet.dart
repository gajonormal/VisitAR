import 'package:flutter/material.dart';
import '../models/filter_options.dart';

const Color kPrimaryGreen = Color(0xFF2E8B57);

class FilterBottomSheet extends StatefulWidget {
  final POIFilter? initialPoiFilter;
  final RoteiroFilter? initialRoteiroFilter;
  final bool showPoiFilters;
  final bool showRoteiroFilters;
  final Function(POIFilter? poiFilter, RoteiroFilter? roteiroFilter) onApply;

  const FilterBottomSheet({
    Key? key,
    this.initialPoiFilter,
    this.initialRoteiroFilter,
    this.showPoiFilters = true,
    this.showRoteiroFilters = false,
    required this.onApply,
  }) : super(key: key);

  @override
  _FilterBottomSheetState createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late POIFilter _poiFilter;
  late RoteiroFilter _roteiroFilter;
  
  // Categorias disponíveis
  final List<String> _categorias = ['Tudo', 'Histórico', 'Natureza', 'Geológico', 'Trilho', 'Gastronomia'];
  final List<String> _dificuldades = ['Qualquer', 'Fácil', 'Moderado', 'Difícil'];

  @override
  void initState() {
    super.initState();
    _poiFilter = widget.initialPoiFilter ?? POIFilter();
    _roteiroFilter = widget.initialRoteiroFilter ?? RoteiroFilter();
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
          // Puxador visual
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
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Filtros", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _poiFilter = POIFilter();
                    _roteiroFilter = RoteiroFilter();
                  });
                },
                child: Text("Limpar", style: TextStyle(color: kPrimaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showPoiFilters) ...[
                    if (widget.showPoiFilters && widget.showRoteiroFilters)
                      const Text("Locais (POIs)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    _buildPoiFilters(),
                    const SizedBox(height: 20),
                  ],
                  if (widget.showRoteiroFilters) ...[
                    if (widget.showPoiFilters && widget.showRoteiroFilters)
                      const Text("Roteiros", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    _buildRoteiroFilters(),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
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
            child: const Text("Aplicar Filtros", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Categoria", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categorias.map((cat) {
            bool isSelected = _poiFilter.categoria == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: kPrimaryGreen.withOpacity(0.2),
              labelStyle: TextStyle(color: isSelected ? kPrimaryGreen : Colors.black87),
              onSelected: (selected) {
                if (selected) setState(() => _poiFilter = _poiFilter.copyWith(categoria: cat));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text("Apenas com Modelo 3D"),
          value: _poiFilter.temModelo3D,
          activeColor: kPrimaryGreen,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _poiFilter = _poiFilter.copyWith(temModelo3D: val)),
        ),
        SwitchListTile(
          title: const Text("Apenas com Áudio"),
          value: _poiFilter.temAudio,
          activeColor: kPrimaryGreen,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _poiFilter = _poiFilter.copyWith(temAudio: val)),
        ),
      ],
    );
  }

  Widget _buildRoteiroFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Dificuldade", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dificuldades.map((dif) {
            bool isSelected = _roteiroFilter.dificuldade == dif;
            return ChoiceChip(
              label: Text(dif),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: kPrimaryGreen.withOpacity(0.2),
              labelStyle: TextStyle(color: isSelected ? kPrimaryGreen : Colors.black87),
              onSelected: (selected) {
                if (selected) setState(() => _roteiroFilter = _roteiroFilter.copyWith(dificuldade: dif));
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

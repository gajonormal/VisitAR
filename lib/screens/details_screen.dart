import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../screens/services/download_service.dart';

class DetailsScreen extends StatefulWidget {
  final POI poi;

  const DetailsScreen({super.key, required this.poi});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  // Variável que guarda o estado: Já está baixado?
  bool isDownloaded = false;
  bool isLoading = false; // Para mostrar um loading enquanto baixa

  @override
  void initState() {
    super.initState();
    _verificarEstadoDownload();
  }

  // Verifica se o ficheiro já existe ao abrir a página
  Future<void> _verificarEstadoDownload() async {
    String fileName = "poi_${widget.poi.id}.glb";
    bool existe = await DownloadService().checkFileExists(fileName);
    if (mounted) {
      setState(() {
        isDownloaded = existe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Imagem de Topo (App Bar flexível)
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            // --- BOTÃO DINÂMICO ---
            actions: [
              // Se estiver a carregar, mostra uma rodinha
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  ),
                )
              else
                IconButton(
                  // Muda o ícone conforme o estado
                  icon: Icon(
                    isDownloaded ? Icons.check_circle : Icons.download_for_offline,
                    color: isDownloaded ? Colors.greenAccent : Colors.white,
                    size: 30,
                    shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                  tooltip: isDownloaded ? "Conteúdo Transferido" : "Baixar Conteúdo",
                  onPressed: () async {
                    
                    // Se já tiver baixado, apenas avisa (Futuramente aqui podes pôr para remover)
                    if (isDownloaded) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Já tens este conteúdo no telemóvel!"))
                      );
                      return;
                    }

                    // Se não tiver, começa o download
                    setState(() { isLoading = true; }); // Ativa rodinha
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("A iniciar download..."))
                    );

                    String fileName = "poi_${widget.poi.id}.glb";
                    // Agora usamos widget.poi porque estamos num State
                    String? path = await DownloadService().downloadFile(widget.poi.arModelUrl, fileName);

                    if (mounted) {
                      setState(() {
                        isLoading = false; // Para rodinha
                        if (path != null) {
                          isDownloaded = true; // <--- MUDA O ÍCONE PARA CHECK
                        }
                      });

                      if (path != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("✅ Download concluído!"))
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("❌ Erro ao baixar."))
                        );
                      }
                    }
                  },
                ),
            ],
            // -----------------------

            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.poi.name, 
                style: const TextStyle(
                  color: Colors.white, 
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)]
                )
              ),
              background: Image.network(
                widget.poi.images.isNotEmpty ? widget.poi.images.first : 'https://via.placeholder.com/300',
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.grey, child: const Center(child: Icon(Icons.error)));
                },
              ),
            ),
          ),

          // 2. Conteúdo da Página
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        widget.poi.category, 
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
                      ),
                      const Spacer(),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      Text(" ${widget.poi.rating}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Descrição",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.poi.description, 
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 30),
                  
                  // Informação Extra
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3))
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.view_in_ar, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isDownloaded 
                              ? "Conteúdo pronto para usar Offline!" 
                              : "Este local tem AR. Faz download para usar sem internet."
                          )
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
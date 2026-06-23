using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

class Program
{
    static readonly UTF8Encoding utf8NoBom = new UTF8Encoding(false);

    static void ProcessFile(string path, Func<string, string> processor)
    {
        if (!File.Exists(path)) return;
        string content = File.ReadAllText(path, Encoding.UTF8);
        string newContent = processor(content);
        if (content != newContent)
        {
            File.WriteAllText(path, newContent, utf8NoBom);
            Console.WriteLine("Fixed " + path);
        }
    }

    static void Main()
    {
        // 1. app_pt.arb
        ProcessFile(@"lib\l10n\app_pt.arb", c => {
            return Regex.Replace(c, "\"noLocationFoundFor\": \"Nenhum local encontrado para\",\r?\n?", "");
        });

        string[] dartFiles = {
            @"lib\screens\roteiros_screen.dart",
            @"lib\screens\explore_screen.dart",
            @"lib\screens\favorites_screen.dart",
            @"lib\screens\login_screen.dart",
            @"lib\screens\roteiro_details_screen.dart",
            @"lib\screens\details_screen.dart",
            @"lib\screens\home_map.dart"
        };

        // 2. Common fixes
        foreach(var file in dartFiles) {
            ProcessFile(file, c => {
                c = c.Replace(".withOpacity(", ".withValues(alpha: ");
                c = c.Replace("(_, __, ___)", "(_, __, e)");
                c = c.Replace("(_, __)", "(_, i)");
                c = Regex.Replace(c, @"\bprint\(", "debugPrint(");
                return c;
            });
        }

        // 3. Specific imports
        ProcessFile(@"lib\screens\explore_screen.dart", c => c.Replace("import 'dart:io';\n", "").Replace("import 'dart:io';\r\n", ""));
        ProcessFile(@"lib\screens\favorites_screen.dart", c => c.Replace("import 'details_screen.dart';\n", "").Replace("import 'details_screen.dart';\r\n", ""));
        ProcessFile(@"lib\screens\roteiro_details_screen.dart", c => {
            c = Regex.Replace(c, "import 'package:geolocator/geolocator.dart';\r?\n", "");
            c = Regex.Replace(c, "import 'package:url_launcher/url_launcher.dart';\r?\n", "");
            return c;
        });
        ProcessFile(@"lib\screens\home_map.dart", c => {
            c = Regex.Replace(c, "import 'package:url_launcher/url_launcher.dart';\r?\n", "");
            c = Regex.Replace(c, "import 'services/database_services.dart';\r?\n", "");
            c = Regex.Replace(c, "import '../screens/services/roteiros_service.dart';\r?\n", "");
            c = c.Replace("zIndex:", "zIndexInt:");
            c = c.Replace("BitmapDescriptor.fromBytes(", "BitmapDescriptor.bytes(");
            
            // Map style
            c = c.Replace("controller.setMapStyle(_mapStyle);", "");
            c = c.Replace("polylines: _polylines,", "polylines: _polylines,\n                style: _mapStyle,");
            
            // Marker scale
            c = c.Replace("return BitmapDescriptor.bytes(data!.buffer.asUint8List());", 
                          "return BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: 2.5);");
            
            return c;
        });

        // 4. GeoLocator desiredAccuracy
        string[] geoFiles = { @"lib\screens\explore_screen.dart", @"lib\screens\details_screen.dart", @"lib\screens\home_map.dart" };
        foreach(var file in geoFiles) {
            ProcessFile(file, c => {
                c = Regex.Replace(c, @"getCurrentPosition\(\s*desiredAccuracy:\s*LocationAccuracy\.(\w+)\s*\)", 
                                  "getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.))");
                c = Regex.Replace(c, @"getCurrentPosition\(\s*desiredAccuracy:\s*LocationAccuracy\.(\w+),", 
                                  "getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.),");
                return c;
            });
        }
    }
}

using System;
using System.IO;
using System.Text;

class Program
{
    static void Main()
    {
        string path = @"lib\l10n\app_pt.arb";
        // The file is currently saved as UTF-8 (no BOM).
        string corrupted = File.ReadAllText(path, new UTF8Encoding(false));
        
        // We know it was corrupted by reading UTF-8 bytes as Windows-1252.
        // So let's extract the Windows-1252 bytes from the characters.
        Encoding win1252 = Encoding.GetEncoding(1252);
        
        // This converts the characters back to the original UTF-8 bytes!
        byte[] originalUtf8Bytes = win1252.GetBytes(corrupted);
        
        // Now decode the original UTF-8 bytes properly.
        string restored = Encoding.UTF8.GetString(originalUtf8Bytes);
        
        // Print a snippet to verify
        Console.WriteLine(restored.Substring(0, 500));
    }
}

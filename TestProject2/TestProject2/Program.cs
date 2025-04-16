using System.Text;
using Snappier;

class Program
{
	static void Main()
	{
		string originalText = "Hello, this is a test string to compress using Snappy!";
		Console.WriteLine("Original: " + originalText);

		// Convert string to byte array
		byte[] inputBytes = Encoding.UTF8.GetBytes(originalText);

		// Compress
		int compressed = Snappy.Compress(input: inputBytes, output: new Span<byte>(new byte[Snappy.GetMaxCompressedLength(inputBytes.Length)]));
		Console.WriteLine("Compressed size: " + compressed);
	}
}
using Newtonsoft.Json;

class Program
{
	static void Main(string[] args)
	{
		// Create a person object
		Person person = new Person
		{
			Name = "Alice",
			Age = 30
		};

		// Serialize the person object to JSON
		string json = JsonConvert.SerializeObject(person);
		Console.WriteLine("Serialized JSON:\n" + json);

		// Deserialize the JSON back to a person object
		Person deserializedPerson = JsonConvert.DeserializeObject<Person>(json);
		Console.WriteLine("\nDeserialized Object:");
		Console.WriteLine($"Name: {deserializedPerson.Name}, Age: {deserializedPerson.Age}");
	}
}

public class Person
{
	public string Name { get; set; }
	public int Age { get; set; }
}
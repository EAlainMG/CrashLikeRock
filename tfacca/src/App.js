import React, { useState } from 'react';
import './App.css';

function App() {
  const [number, setNumber] = useState(0);

  const incrementNumber = async () => {
    try {
      console.log("Hostname:", window.location.hostname);
      const backendPath = "/increment"; 
      const backendUrl = `http://${window.location.hostname}${backendPath}`;
      console.log("Backend URL:", backendUrl);
      const response = await fetch(backendUrl)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      setNumber(data.number);
    } catch (error) {
      console.error("Error fetching data: ", error);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <p>Number: {number}</p>
        <button onClick={incrementNumber}>
          Increment & Retrieve
        </button>
      </header>
    </div>
  );
}

export default App;
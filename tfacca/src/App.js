import React, { useState } from 'react';
import './App.css';

function App() {
  const [number, setNumber] = useState(0);

  const incrementNumber = async () => {
    try {
      const response = await fetch('http://localhost:3000/increment');
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
          Increment
        </button>
      </header>
    </div>
  );
}

export default App;
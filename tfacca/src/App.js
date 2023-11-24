import React, { useState } from 'react';
import './App.css';

function App() {
  const [number, setNumber] = useState(0);

  const incrementNumber = async () => {
    const response = await fetch('http://backend-service:3000/increment');
    const data = await response.json();
    setNumber(data.number);
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
import { useState, useEffect } from 'react';
import { focusPeer_backend } from 'declarations/focusPeer_backend';

function App() {
  const [greeting, setGreeting] = useState('');
  const [points, setPoints] = useState(0);
  const [userId, setUserId] = useState(''); // Store user ID
  const [isUsingPhone, setIsUsingPhone] = useState(false); // Track phone usage
  const [sessionActive, setSessionActive] = useState(false); // Track session status

  useEffect(() => {
    // Simulate fetching or registering a user to get userId
    const fetchUserId = async () => {
      const newUserId = await focusPeer_backend.registerUser('User'); // Replace with actual username input if needed
      setUserId(newUserId);
    };
    fetchUserId();
  }, []);

  useEffect(() => {
    let interval;

    if (sessionActive) {
      // Adjust points every 5 seconds if session is active
      interval = setInterval(async () => {
        const result = await focusPeer_backend.adjustPoints(userId, isUsingPhone);
        setPoints(result); // Update points state with result
        console.log("Points adjusted:", result);
      }, 5000);
    }

    return () => clearInterval(interval); // Clean up on unmount or session end
  }, [sessionActive, isUsingPhone, userId]);

  const handleSubmit = async (event) => {
    event.preventDefault();
    const name = event.target.elements.name.value;

    const greetingMessage = await focusPeer_backend.greet(name);
    setGreeting(greetingMessage);
  };

  const startSession = async () => {
    const duration = 1; // Set the desired session duration
    const result = await focusPeer_backend.startSession(userId, duration);
    console.log("Session started:", result);
    setSessionActive(result);
  };

  const endSession = async () => {
    const result = await focusPeer_backend.endSession(userId);
    console.log("Session ended:", result);
    setSessionActive(false);
  };

  const handleMouseMove = () => {
    setIsUsingPhone(true); // User is using the phone
  };

  const handleBeforeUnload = async () => {
    await focusPeer_backend.adjustPoints(userId, false); // Adjust points on window close
  };

  useEffect(() => {
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, []);

  return (
    <main>
      <img src="/logo2.svg" alt="DFINITY logo" />
      <h1>Welcome to Focus Peer</h1>
      <form onSubmit={handleSubmit}>
        <label htmlFor="name">Enter your name: &nbsp;</label>
        <input id="name" type="text" required />
        <button type="submit">Submit</button>
      </form>
      <section id="greeting">{greeting}</section>
      <section className="points">Current Points: {points}</section>
      <div>
        <button onClick={startSession}>Start Session</button>
        <button onClick={endSession}>End Session</button>
        <p>User ID: <span>{userId}</span></p>
      </div>
    </main>
  );
}

export default App;

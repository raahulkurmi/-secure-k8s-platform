import { useState, useEffect } from 'react';

const API = import.meta.env.VITE_API_URL || '/api';

export default function App() {
  const [todos, setTodos]   = useState([]);
  const [input, setInput]   = useState('');
  const [error, setError]   = useState('');
  const [loading, setLoading] = useState(true);

  const fetchTodos = async () => {
    try {
      const res = await fetch(`${API}/todos`);
      const data = await res.json();
      setTodos(data);
    } catch {
      setError('Failed to load todos');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchTodos(); }, []);

  const addTodo = async (e) => {
    e.preventDefault();
    if (!input.trim()) return;
    try {
      const res = await fetch(`${API}/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: input.trim() }),
      });
      const todo = await res.json();
      setTodos([todo, ...todos]);
      setInput('');
    } catch {
      setError('Failed to add todo');
    }
  };

  const toggleTodo = async (id) => {
    try {
      const res = await fetch(`${API}/todos/${id}`, { method: 'PATCH' });
      const updated = await res.json();
      setTodos(todos.map(t => t.id === id ? updated : t));
    } catch {
      setError('Failed to update todo');
    }
  };

  const deleteTodo = async (id) => {
    try {
      await fetch(`${API}/todos/${id}`, { method: 'DELETE' });
      setTodos(todos.filter(t => t.id !== id));
    } catch {
      setError('Failed to delete todo');
    }
  };

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>🔐 Secure Todo</h1>
      <p style={styles.subtitle}>Running on Kubernetes · Secured by Kyverno + Falco</p>

      {error && <div style={styles.error}>{error}</div>}

      <form onSubmit={addTodo} style={styles.form}>
        <input
          style={styles.input}
          value={input}
          onChange={e => setInput(e.target.value)}
          placeholder="Add a new todo..."
        />
        <button style={styles.button} type="submit">Add</button>
      </form>

      {loading ? (
        <p style={styles.loading}>Loading...</p>
      ) : todos.length === 0 ? (
        <p style={styles.empty}>No todos yet. Add one above!</p>
      ) : (
        <ul style={styles.list}>
          {todos.map(todo => (
            <li key={todo.id} style={styles.item}>
              <span
                onClick={() => toggleTodo(todo.id)}
                style={{ ...styles.todoText, textDecoration: todo.completed ? 'line-through' : 'none', opacity: todo.completed ? 0.5 : 1 }}
              >
                {todo.title}
              </span>
              <button onClick={() => deleteTodo(todo.id)} style={styles.deleteBtn}>✕</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

const styles = {
  container:  { maxWidth: 600, margin: '60px auto', fontFamily: 'system-ui, sans-serif', padding: '0 20px' },
  title:      { fontSize: 32, fontWeight: 700, marginBottom: 4 },
  subtitle:   { color: '#666', fontSize: 13, marginBottom: 24 },
  error:      { background: '#fee', border: '1px solid #fcc', padding: 12, borderRadius: 6, marginBottom: 16, color: '#c00' },
  form:       { display: 'flex', gap: 8, marginBottom: 24 },
  input:      { flex: 1, padding: '10px 14px', fontSize: 16, border: '1px solid #ddd', borderRadius: 6, outline: 'none' },
  button:     { padding: '10px 20px', background: '#2563eb', color: '#fff', border: 'none', borderRadius: 6, fontSize: 16, cursor: 'pointer' },
  loading:    { color: '#888', textAlign: 'center' },
  empty:      { color: '#888', textAlign: 'center' },
  list:       { listStyle: 'none', padding: 0, margin: 0 },
  item:       { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 16px', border: '1px solid #eee', borderRadius: 6, marginBottom: 8, background: '#fafafa' },
  todoText:   { cursor: 'pointer', fontSize: 16, flex: 1 },
  deleteBtn:  { background: 'none', border: 'none', color: '#999', fontSize: 18, cursor: 'pointer', padding: '0 4px' },
};

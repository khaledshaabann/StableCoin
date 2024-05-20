import {useState, useEffect} from 'react';
import Web3 from 'web3';
import { BrowserRouter as Router, Route, Routes, Navigate } from 'react-router-dom';
import './App.css';
import {contractAddress, contractAbi} from './constant/constant.js'
import  Dashboard  from './Dashboard.jsx';



const App = () => {
  
  const [account, setAccount] = useState('');
  const [contract, setContract] = useState(null);
  const[error, setError] = useState(null);

  useEffect(() => {
    const loadBlockchainData = async () => {
      if (window.ethereum) {
        const web3 = new Web3(window.ethereum);
        try {
          await window.ethereum.request({ method: 'eth_requestAccounts' }); // Request account access
          const accounts = await web3.eth.getAccounts();
          setAccount(accounts[0]); // Changed to index 0, assuming admin account is first

          const contractInstance = new web3.eth.Contract(contractAbi, contractAddress);
          setContract(contractInstance);

          
        } catch (error) {
          console.error('Error connecting to MetaMask:', error);
          setError('Error connecting to MetaMask. Please try refreshing the page or make sure MetaMask is properly installed.');
        }
      } else {
        setError('MetaMask is not installed. Please install MetaMask to use this application.');
      }
    };

    loadBlockchainData();
  }, []);

  return (
      <div className='App'>
        <Router>
          <Routes>
            <Route path='/Dashboard' element={<Dashboard account={account} contract={contract} error={error} />} />
\
            <Route path='*' element={<Navigate to='/Dashboard' />} />
          </Routes>
        </Router>
        
      </div>
  );
};

export default App;
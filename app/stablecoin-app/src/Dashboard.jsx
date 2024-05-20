import React, { useState, useEffect } from 'react';
import Web3 from 'web3';

const Dashboard = ({ contract, account }) => {
  const [address, setAddress] = useState('');
  const [userData, setUserData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [collateralAmount, setCollateralAmount] = useState('');
  const [depositLoading, setDepositLoading] = useState(false);
  const [depositError, setDepositError] = useState('');
  const [success, setSuccess] = useState('');
  const [Mintamount, setMintamount] = useState('');
  const [loadingMint, setLoadingMint] = useState(false);
  const [errorMint, setErrorMint] = useState('');
  const [Mintsuccess, setMintSuccess] = useState('');
  const [loadinghfactor, setLoadinghfactor] = useState('false');
  const [errorhfactor, setErrorhfactor] = useState('');
  const [newhfactor, setnewhfactor] = useState(null);
  const [burnamount, setBurnamount] = useState('');
  const [loadingBurn, setLoadingBurn] = useState(false);
  const [errorBurn, setErrorBurn] = useState('');
  const [BurnSuccess, setBurnSuccess] = useState('');


  

  // Load User Data
  const loadUserData = async () => {
    setLoading(true);
    setError('');
  
    try {
      const userDataObject = await contract.methods.getAccountInformation('0xBF9D8E8fC717773242E9584dC90FbD50455F9418').call();
      const DSC = userDataObject[0].toString(); // Convert uint256 to string
      const Collateral = userDataObject[1].toString();
  
      console.log("User data:", { DSC, Collateral });
  
      setUserData({ DSC, Collateral });
    } catch (error) {
      console.error('Error fetching user details:', error);
      setError('An error occurred while fetching user details. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleUserDetailsButtonClick = () => {
    loadUserData();
  };

  // Deposit Collateral
  const handleDepositSubmit = async (e) => {
    e.preventDefault();
    setDepositLoading(true);
    setDepositError('');
    setSuccess('');

    try {
      const web3 = new Web3(window.ethereum);

      // Parse numeric values
      const tokenAddress = '0xdd13E55209Fd76AfE204dBda4007C227904f0a81';
      const amount = web3.utils.toWei(collateralAmount, 'ether'); // Assuming the amount is in ether

      // Call the depositCollateral function
      await contract.methods.depositCollateral(
        tokenAddress,
        amount
      ).send({ from: '0xBF9D8E8fC717773242E9584dC90FbD50455F9418' });

      setSuccess('Collateral deposited successfully');
    } catch (error) {
      console.error('Error adding data:', error);
      setDepositError('An error occurred while adding data. Please try again.');
    } finally {
      setDepositLoading(false);
    }
  };
  const handleMintSubmit = async (e) => {
      e.preventDefault();
      setLoadingMint(true);
      setErrorMint('');
      setSuccess('');
  
      try {
  
        // Parse numeric values
        const amount = parseInt(Mintamount, 10); 
        
        // Call the depositCollateral function
        await contract.methods.mintDsc(amount).send({ from: '0xBF9D8E8fC717773242E9584dC90FbD50455F9418' });
  
        setMintSuccess('Minted successfully');
      } catch (error) {
        console.error('Error adding data:', error);
        setErrorMint('An error occurred while adding data. Please try again.');
      } finally {
        setLoadingMint(false);
      }
    };

    const handleBurnSubmit = async (e) => {
      e.preventDefault();
      setLoadingBurn(true);
      setErrorBurn('');
      setSuccess('');
  
      try {
  
        // Parse numeric values
        const amount = parseInt(burnamount, 10); 
        
        // Call the depositCollateral function
        await contract.methods.burnDsc(amount).send({ from: '0xBF9D8E8fC717773242E9584dC90FbD50455F9418' });
  
        setBurnSuccess('Burned successfully');
      } catch (error) {
        console.error('Error adding data:', error);
        setErrorBurn('An error occurred while adding data. Please try again.');
      } finally {
        setLoadingBurn(false);
      }
    };

  

  return (
    <div>
    <h1>StableCoin Wallet</h1>
    <div className='Dashboard'>
      <div className='Details'>
        <div className="container1">
          <h1>User Details</h1>
          <button className='UserBtn' onClick={handleUserDetailsButtonClick}>Get User Details</button>
          {loading ? (
            <p>Loading...</p>
          ) : error ? (
            <p className="error">{error}</p>
          ) : userData ? (
            <div>
              <p className='output'><strong>DSC:</strong> {userData.DSC}</p>
              <p className='output'><strong>Collateral:</strong> {userData.Collateral}</p>
            </div>
          ) : null}
        </div>
      </div>
      
      <div className='Deposit'>
        <div className="Box">
          <h1>Deposit</h1>
          <form className='Form-con' onSubmit={handleDepositSubmit}>
            <div className='form-group'>
              <label className='Label'>Collateral Amount:</label>
              <input 
                type="text" 
                className='Data' 
                value={collateralAmount} 
                onChange={(e) => setCollateralAmount(e.target.value)} 
              />
            </div>
            <button type="submit" className="btn" disabled={depositLoading}>
              {depositLoading ? 'Submitting...' : 'Submit'}
            </button>
          </form>
          {depositError && <p className="error">{depositError}</p>}
          {success && <p className="success">{success}</p>}
        </div>
      </div>
    
  
      <div className='Minting'>
        <div className="Box">
          <h1>Minting</h1>
          <form className='Form-con' onSubmit={handleMintSubmit}>
            <div className='form-group'>
              <label className='Label'>Mint Amount:</label>
              <input 
                type="text" 
                className='Data' 
                value={Mintamount} 
                onChange={(e) => setMintamount(e.target.value)} 
              />
            </div>
            <button type="submit" className="btn" disabled={loading}>
              {loading ? 'Submitting...' : 'Submit'}
            </button>
          </form>
          {error && <p className="error">{error}</p>}
          {success && <p className="success">{success}</p>}
        </div>
        
      </div>
      <div className='Burning'>
        <div className="Box">
          <h1>Burning</h1>
          <form className='Form-con' onSubmit={handleBurnSubmit}>
            <div className='form-group'>
              <label className='Label'>Burn Amount:</label>
              <input 
                type="text" 
                className='Data' 
                value={burnamount} 
                onChange={(e) => setBurnamount(e.target.value)} 
              />
            </div>
            <button type="submit" className="btn" disabled={loading}>
              {loading ? 'Submitting...' : 'Submit'}
            </button>
          </form>
          {error && <p className="error">{error}</p>}
          {success && <p className="success">{success}</p>}
        </div>
        
      </div>
      
      </div>
      </div>
  );
};

export default Dashboard;

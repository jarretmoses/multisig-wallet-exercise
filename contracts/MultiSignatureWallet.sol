// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract MultiSignatureWallet {
    struct Transaction {
      bool executed;
      address destination;
      uint value;
      bytes data;
    }

    address[] private owners;
    uint private required;
    uint public transactionCount;
    uint private requiredCount;

    mapping(uint => Transaction) public transactions;
    mapping (address => bool) public isOwner;
    mapping (uint => mapping (address => bool)) public confirmations;

    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    /// @dev Fallback function allows to deposit ether.
    fallback() external payable {
      if (msg.value > 0) {
        emit Deposit(msg.sender, msg.value);
      }
    }

    // TODO: Do I need this?
    receive() external payable {}

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(
      address[] memory _owners,
      uint _required
    ) validRequirement(_owners.length, _required) {
      owners = _owners;
      required = _required;

      for (uint i = 0; i < _owners.length; i++) {
        isOwner[_owners[i]] = true;
      }
    }

    modifier validRequirement(uint _owners, uint _required) {
      if (_required > _owners || _required == 0 || _owners == 0) {
        revert();
      }

      _;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId - Returns transaction ID.
    function submitTransaction(
      address destination,
      uint value,
      bytes memory data
    ) public returns (uint transactionId) {
      require(isOwner[msg.sender]);

      transactionId = addTransaction(destination, value, data);
      confirmTransaction(transactionId);

      return transactionId;
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
      require(isOwner[msg.sender]);
      require(transactions[transactionId].destination != address(0));
      require(confirmations[transactionId][msg.sender] == false);
      confirmations[transactionId][msg.sender] = true;

      emit Confirmation(msg.sender, transactionId);

      executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {
      require(isOwner[msg.sender]);

      confirmations[transactionId][msg.sender] = false;
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
      require(transactions[transactionId].executed == false);

      if (isConfirmed(transactionId)) {
        Transaction storage t = transactions[transactionId];
        t.executed = true;
        (bool success, ) = t.destination.call{value: t.value}(t.data);

        if (success) {
          emit Execution(transactionId);
        } else {
          t.executed = false;
          emit ExecutionFailure(transactionId);
        }
      }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
      uint count = 0;

      for(uint i; i < owners.length; i++) {
        address ownerAddress = owners[i];

        if (confirmations[transactionId][ownerAddress]) {
          count++;
        }

        if (count == required) {
          return true;
        }
      }

      return false;
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId - Returns transaction ID.
    function addTransaction(
      address destination,
      uint value,
      bytes memory data
    ) internal returns (uint transactionId) {
      transactionId = transactionCount;

      transactions[transactionId] = Transaction({
        destination: destination,
        value: value,
        data: data,
        executed: false
      });
      transactionCount += 1;

      emit Submission(transactionId);
    }
}

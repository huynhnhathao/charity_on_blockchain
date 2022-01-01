//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

contract VendingMachine {
    // this contract represent one product with one predefined
    // price in wei. To buy products from this contract,
    // people can send a purchase request, send ether and a message
    // tell where should the product be delivered. The owner will
    // withdraw ether from this contract, take the message and deliver
    // products later.

    // owner can withdraw money one by one booking, get the booking information
    // execute the purchase,
    // we use one currentIndex to discriminate between already processed and
    // unprocessed bookings. Bookings that after that index are unprocessed
    // and before that index are processed

    struct Booking {
        address customerAddress;
        uint256 numProduct;
        uint256 receivedWei;
        string message;
        uint256 bookingId;
        bool processed;
    }

    // name of the product
    string public name;
    // price of this produce
    uint256 public price;
    // number of product remaining in stock
    uint256 public stock;
    // owner of this vending machine
    address owner;

    Booking[] allBookings;
    // any booking after this index is unprocessed,
    // before this index is processed
    uint256 currentIndex;

    modifier onlyOwner() {
        require(msg.sender == owner, "Access denied.");
        _;
    }

    event receivedWei(uint256 amount);
    event successfullyBooked(
        uint256 bookingId,
        address customerAddress,
        uint256 _numProduct,
        uint256 totalAmount,
        uint256 tip,
        string message,
        bool processed
    );
    event Refunded(uint256 bookingId);
    event ThisBookingWasProcessed(uint256 bookingId);

    error CustomerNotExist(address customer);
    error AlreadyWithdrawed();
    error ArrayIndexOutOfRange(uint256 index);
    error OutOfStock();
    error NotEnoughWei(uint256 required, uint256 received);
    error ThereAreUnprocessedBookings(uint256 numUnprocessedBookings);
    error NotFoundCustomer(address customerAddress);
    error BookingAlreadyProcessed(
        uint256 bookingId,
        address customerAddress,
        uint256 _numProduct,
        uint256 totalAmount,
        string message,
        bool processed
    );

    constructor(
        string memory _name,
        uint256 _price,
        uint256 _stock
    ) {
        name = _name;
        price = _price;
        stock = _stock;
        owner = msg.sender;
    }

    receive() external payable {}

    fallback() external payable {}

    function book(uint256 _numProduct, string memory _message) public payable {
        // customer booking via this function
        // the wei required = _numProduct * price
        // any residual wei are considered tip

        // log the booking as confirmation

        require(_numProduct > 0, "Number of products must be larger than 0.");

        if (stock == 0) {
            revert OutOfStock();
        }

        uint256 requiredValue = _numProduct * price;

        if (msg.value < requiredValue) {
            revert NotEnoughWei(requiredValue, msg.value);
        }

        stock -= _numProduct;

        Booking memory _booking = Booking({
            customerAddress: msg.sender,
            numProduct: _numProduct,
            receivedWei: msg.value,
            message: _message,
            bookingId: allBookings.length,
            processed: false
        });

        allBookings.push(_booking);

        emit successfullyBooked(
            _booking.bookingId,
            _booking.customerAddress,
            _booking.numProduct,
            requiredValue,
            msg.value - requiredValue,
            _booking.message,
            _booking.processed
        );
    }

    function requestRefund() public {
        // customer can withdraw their booking if it's still not be
        // processed. Assume that customer has only one booking

        for (uint256 i = 0; i < allBookings.length; i++) {
            if (msg.sender == allBookings[i].customerAddress) {
                Booking storage _booking = allBookings[i];
                if (_booking.processed) {
                    revert BookingAlreadyProcessed(
                        _booking.bookingId,
                        _booking.customerAddress,
                        _booking.numProduct,
                        _booking.receivedWei,
                        _booking.message,
                        _booking.processed
                    );
                } else {
                    // refund customer
                    _booking.processed = true;
                    payable(msg.sender).transfer(_booking.receivedWei);
                    emit Refunded(_booking.receivedWei);
                }
            } else revert CustomerNotExist(msg.sender);
        }
    }

    function ownerGetBooking()
        public
        onlyOwner
        returns (
            address,
            uint256,
            uint256,
            string memory message,
            uint256
        )
    {
        // owner call this function to withdraw customer's booking
        // and its ether.
        // return the oldest unprocessed booking from allBookings
        // increase current index 1 unit
        // send all received wei in the returned booking to the owner

        // since only the owner can call this function, don't worry about malicious attack
        require(
            currentIndex < allBookings.length,
            "All booking have processed."
        );

        Booking storage _booking = allBookings[currentIndex];

        if (_booking.processed) {
            currentIndex += 1;
            emit ThisBookingWasProcessed(_booking.bookingId);
        }
        currentIndex += 1;
        _booking.processed = true;
        payable(msg.sender).transfer(_booking.receivedWei);
        return (
            _booking.customerAddress,
            _booking.numProduct,
            _booking.receivedWei,
            _booking.message,
            _booking.bookingId
        );
    }

    function getBalance() public view onlyOwner returns (uint256) {
        // get the current balance of this vending machine
        return address(this).balance;
    }

    function updatePrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    function updateStock(uint256 newStock) public onlyOwner {
        stock = newStock;
    }

    function getNumUnprocessedBookings()
        public
        view
        onlyOwner
        returns (uint256)
    {
        return allBookings.length - currentIndex;
    }

    function getNumProcessedBookings() public view onlyOwner returns (uint256) {
        return currentIndex;
    }

    function endContract() public onlyOwner {
        // can not destroy this contract if there are remaining
        // unprocessed bookings
        if (currentIndex + 1 < allBookings.length) {
            revert ThereAreUnprocessedBookings(getNumUnprocessedBookings());
        }
        // expect no ether left if no one send ether via
        // the receive() function
        selfdestruct(payable(msg.sender));
    }
}

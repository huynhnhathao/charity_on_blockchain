# Embrace the Transparency in Charity Funds

## Compare to normal charity fundraising

The donors want her money to goes directly to the intended beneficiaries, without dropping any cent along the track from donors to beneficiaries.

### Normal fundraising:

- Everything is based on trust

- Control by an organization or one single entity, they/he advertising the campaign, then gathering money from donors and distributing money to the qualified beneficiaries that satisfied the project's criteria.

- **Disadvantage**:

  - The project manager may dishonest and use the raised money for other purposes that do not compliance with the project's purposes.
  - The donors have to trust the organization/entity that manage the fund, they don't have direct information where their money will end up.
  - There are many intermediaries between the donors and the beneficiaries, such as the fundraiser,...

  

### Smartcontract Fundraiser 

- Developed by the programmer, source code is public to increase transparent, once deployed no one can make change to the agreements specified in the contract.
- **Advantage**
  - No need for trust, everything specified in the contract will be executed when the conditions are met. No one can maliciously tamper the contract conditions.
  - Ether can goes directly from the Smartcontract to the beneficiaries, no more intermediaries.
- **Disadvantage**: 
  - Conversion from national currency to Ethereum?

The supplier can upload the invoice, delivery note and other documents that
can be viewed and downloaded by the association or by all donors  

How to make sure that one people only gets one package? use phone verification via sms.

Everyone can initiate a fundraising campaign, 

tracking and certifying the entire flow of donation, from its payment to its use.

it allows donors to donate in total safety and to constantly monitor, comment and verify the development of each specific social project,  

## FundMe

provider is a contract, it receive ether and require information, 

Smart contract that predefine its purpose: buy hospital equipment for a specific hospital from a specific provider. First the fund raising campaign is initiated, everyone can takes part in and become a donors until deadline or enough fund. When the campaign has enough fund, it send a predefined request and all of its money to the provider, books a set of predefined products, then the provider ship the booked products and send the app a receipts, and the hospital send the project owner a confirmation of receiving the products.



state variables:

- creator
- beneficiary
- creationTime
- campaignDuration
- campaignDeadline
- requiredFundAmount
- anynomousFundedAmount
- minDonation
- bool campaignEnded



events:

- received ether
- not enough ether
- return the residual ether
- raised enough ether
- deadline of the campaign and not enough ether

functions:

- donate: take money, add save the donor address mapping to the donated amount, check amount/deadline, if enough amount, send money to the provider as promise, if deadline but not enough money, returns all the money back to donors, minus the gas fee of receiving and return ether.
- return money to donors
- The last donor may donate more than needed, only takes the amount that add up to the raised amount, return the residual to the last donor.
- getRequireAmountInWei
- withdraw ability

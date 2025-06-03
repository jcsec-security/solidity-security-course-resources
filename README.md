# Faillapop - Solidity mock audit environment!

We sometimes feel that the jump between being able to identify issues in small snippets of code and auditing a more complex codebase is problematic. There are a loooot of small CTF-like exercises, some easy some really difficult, but feel like there is a lack of a "mock audit contract" for people to practice their skills in a closer to real-life project. 

So we decided to create the Faillapop protocol!

> [!WARNING]
> The code has been made vulnerable on purpose. Please do not deploy or reuse this codebase in a live environment.

---

## The Faillapop protocol 🛍️

The Faillapop protocol is a vulnerable-by-design protocol to help Web3 security students practice their skills in a fun environment. The protocol is composed of multiple contracts that interact with each other to create a decentralized buying and selling platform. Disputes are resolved through a DAO and malicious sellers are checked by forcing a deposit before selling anything... but there have been a lot of bad decisions during this process :mag:. 


You will find common solidity security issues, dubious centralization and logical loopholes. Do not forget to think about others such as flash loans and Out-Of-Gas exceptions! 

Try to perform a full mock audit! Create your own professional report mimicking those of well-known companies such as Oak Security, Trail of Bits, Hacken, or Halborn. Imagine that you are getting paid for this and trying to do the best job possible! not just finding bugs but also crafting proper paragraphs for your report. 


Solutions are not provided along this repo but the documentation has been created following the NatSpec format and the following diagram will help you get a grasp of the whole architecture.


![Faillapop diagram](Faillapop_diagram_v3.svg)


> [!TIP]
> Do not forget to run and analyze the testing suite. Sometimes you can spot vulnerabilities just by checking the bits that were neglected during testing and ensuring they behave as expected, or just reviewing failed tests.

## Working with the Faillapop Protocol 🛠️

The Faillapop protocol uses the Foundry framework. 

>**Why Foundry?**
>- It is the fastest framework
>- Allows writing tests and scripts in Solidity, minimising context switches
>- It has a lot of cheatcodes for testing and debugging

Foundry is composed of four components:
- [**Forge**](https://github.com/foundry-rs/foundry/blob/master/crates/forge): Ethereum Testing Framework
- [**Cast**](https://github.com/foundry-rs/foundry/blob/master/crates/cast): A command line tool for making RPC calls to Ethereum. Allowing to interact with smart contracts, send transactions or retrieve any kind of data from the Blockchain through the console
- [**Anvil**](https://github.com/foundry-rs/foundry/blob/master/crates/anvil): A local Ethereum node, similar to Ganache, which is deployed by default during test execution
- [**Chisel**](https://github.com/foundry-rs/foundry/blob/master/crates/chisel): A solidity REPL, very fast and useful during contract development or testing

To work with the Faillapop protocol, follow these steps:

### 1. Install Foundry Framework

The recommended way to install it is using the **foundryup** tool. Below we will go through the installation step by step, but if you want to do a dependency-free installation, you can follow the installation instructions from [this repository](https://github.com/hardenerdev/smart-contract-auditor).

> [!NOTE]
> If you are using Windows, you will need to install and use [Git BASH](https://gitforwindows.org/) or [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) as the terminal, as Foundryup does not support Powershell or Cmd.

In the terminal run:

```Powershell
curl -L https://foundry.paradigm.xyz | bash
```

As a result you will get something like this:

```shell
consoleDetected your preferred shell is bashrc and added Foundry to Path run:source /home/user/.bashrcStart a new terminal session to use Foundry
```

Now simply type `foundryup` in the terminal and press `Enter`. This will install the four Foundry components: *forge*, *cast*, *anvil* and *chisel*.

To confirm the correct installation, type `forge --version`. You should get the installed version of forge:

```shell 
Forge version x.x.x
```
If you have not obtained the version, you may need to add Foundry to your PATH. To do this, you can run the following:

```shell
cd ~echo 'source /home/user/.bashrc' >> ~/.bash_profile
```

If you still have problems with the installation, you can follow Foundry's installation instructions in their [repository](https://book.getfoundry.sh/getting-started/installation).

### 2. Set Up the Project

Clone the repository to your local machine:

```shell
git clone https://github.com/jcsec-security/faillapop.git
cd faillapop
```

Install dependencies and compile the project using Foundry:

```shell
forge build
```

### 3. Run the Tests

To run the test suite, use the following command:

```shell
forge test
```

This will run all the tests in the `tests` directory. 

---

For further documentation on the protocol --> [Faillapop Documentation](./docs/README.md)


## Next steps

The current version is `v1.0`. At the moment we would like to achieve the below in order to upgrade it:


:pushpin:`V2.0`

- Oracle
- Flash loan provider

## Contribution and Contact

We encourage you to make the most of this material. If you find it useful, feel free to share by linking to this repository. Your feedback is invaluable! If you have suggestions, corrections, or would like to contribute in any way, please don't hesitate to reach out:

- Telegram: @jcr_auditor
- Email:  jc@jcsec.io

Thank you for exploring this repository, and happy bug hunting!

## Collaboration

On September 2023 the [NICS lab](https://www.nics.uma.es/) research group from the [University of Malaga](https://www.uma.es/) agreed to help improving this repository as part of their efforts on Open Source collaboration. In particular, with new versions of the Faillapop mock-audit environment, both improving the initial codebase and extending its features.

> [!IMPORTANT]  
> Special thanks to Marco Lopez ([TW](https://twitter.com/Marcologonz), [LD](https://linkedin.com/in/marcologonz)) who took on this workload as part of his dissertation and to NICS Lab's researcher Isaac Agudo who supported and pushed for the initiative to come to success.

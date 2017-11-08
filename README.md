# bluenet-example-ios

A Crownstone test app that uses the bluenet-ios-lib.

This example has a GUI so you can test some functions from bluenet directly. It is an app we use for development. It has one view and uses many features of the bluenet-ios-lib.

Yes, the UI is a little flunky and if you press the buttons before the command has finished, there can be errors. There is not a lot of UI code to address these items in order not to overshadow the usage of the bluenet lib.

#### Important to note:
The simulator does not support Bluetooth and navigation passthrough so you'll have to load it on an actual phone to see what's happening.

# Getting started

The Bluenet ios lib uses Carthage to handle it's dependencies. It's also the way you install Bluenet ios in other projects.
If you're unfamiliar with Carthage, take a look at the project here: https://github.com/Carthage/Carthage

To get the Bluenet ios examples up and running, first you need to have Carthage installed.

Once this is finished, run the following command in your terminal (in the same folder as the Cartfile)

```
carthage bootstrap --platform iOS --no-use-binaries
```

All dependencies will then be downloaded, built and placed in a Carthage/Build folder.


# API docs

All documentation on the use of the lib can be found in it's repository:
https://github.com/crownstone/bluenet-lib-ios


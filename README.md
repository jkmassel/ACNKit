# ACNKit

A simple library for working with streaming ACN in Swift. 

Heavily relies on the fantastic [libe131](https://github.com/hhromic/libe131) library.


#### Functionality

#### Examples

Create a universe and listen for channel value changes.

```swift

let universe = DMXUniverse(number: 1)

universe.listener = { universe in
  
  let channel1Value = universe.valueForChannel(1)

  debugPrint(channel1Value.percent) // Get the value of a channel as a percent.
  debugPrint(channel1Value.absoluteValue) // A UInt8 with the value between 0 and 255.
}

universe.startListeningForChanges()

```

#### Troubleshooting

**My listener is never called**
You'll need to have a device (likely a lighting console) generating an sACN stream on your local network before you'll be able to use this library.

#### Known issues
- [ ] This library doesn't always work properly on devices with more than one network interface.
- [ ] Channel values are currently only read-only.
- [ ] Tests are lacking
- [ ] The logs are pretty chatty - this will be replaced by hooks


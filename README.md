
Add the following to your `build.settings`

```
{
    plugins = {
        ["profiler"] = {
            publisherId = "com.solar2-plugin",
        },
    },
}
```

You implement the plugin in your scene like this

```
  myProfiler = profiler.new()
```

You can add these optional parameters to customize the plugin

* `frames` This decides how many frames to gather data into a single data point.  Defaults to 30.
* `alpha` This sets the alpha for the graph.  Defaults to 1.
* `colour1`, `colour2` `colour3` These override the default graph colours.

So a full version would look like this

```
myProfiler = profiler.new({frames = display.fps, colour1 = {1,0,0}, colour2 = {0,1,0}, colour3 = {0,0,1}, alpha = 0.6})
```

You can move, scale and transform the profiler after creation.

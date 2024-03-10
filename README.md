# Basic Tiled Loader

Basic Tiled Loader (btl) is a library to load [Tiled](https://github.com/mapeditor/tiled) files. 

I have 2 main goals with btl, as this functionality seems missing in other Lua-based Tiled loaders:

- Handle [infinite maps](https://doc.mapeditor.org/en/stable/manual/using-infinite-maps/) efficiently.

- Allow usage of a custom camera (currently supporting only [hump.camera](https://hump.readthedocs.io/en/latest/camera.html))

The current implementation only supports rendering orthogonal maps, but perhaps other map types will render correctly. 

The code is inspired by the [TiledMapLoader](https://love2d.org/wiki/TiledMapLoader) example as a starting point. To parse XML files, I've added a modified version of the [XMLParser code from Alexander Makeev](http://lua-users.org/wiki/LuaXml).

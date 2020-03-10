class ThrowsNonexistent {

    __Call(method:="") {
        if method not in Insert,Remove,MinIndex,MaxIndex,SetCapacity ,GetCapacity,GetAddress,_NewEnum,HasKey,Clone
		{
            throw Exception("Non-existent method", -1, method)
		}
    }
	
}
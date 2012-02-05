//
//  PGArc.h
//  PGMidi
//

#pragma once

#if __has_feature(objc_arc)

template <typename OBJC_TYPE, typename SOURCE_TYPE>
OBJC_TYPE *arc_cast(SOURCE_TYPE *source)
{
    return (__bridge OBJC_TYPE*)source;
}

#else

template <typename OBJC_TYPE, typename SOURCE_TYPE>
OBJC_TYPE *arc_cast(SOURCE_TYPE *source)
{
    return (OBJC_TYPE*)source;
}

#endif

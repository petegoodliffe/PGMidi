//
//  PGArc.h
//  PGMidi
//

#pragma once

//==============================================================================
// Cope gracefully if we're not using LLVM3

#ifndef __has_feature
    #define __has_feature(x) 0
#endif

#ifndef __has_extension
    #define __has_extension __has_feature
#endif

#if __has_feature(objc_arc) && __clang_major__ >= 3
    #define PGMIDI_ARC 1
#else
    #define PGMIDI_ARC 0
#endif

//==============================================================================
#if PGMIDI_ARC

#ifdef __cplusplus

template <typename OBJC_TYPE, typename SOURCE_TYPE>
inline
OBJC_TYPE *arc_cast(SOURCE_TYPE *source)
{
    return (__bridge OBJC_TYPE*)source;
}

#endif


//==============================================================================
#else

#ifdef __cplusplus

template <typename OBJC_TYPE, typename SOURCE_TYPE>
inline
OBJC_TYPE *arc_cast(SOURCE_TYPE *source)
{
    return (OBJC_TYPE*)source;
}

#endif

#endif

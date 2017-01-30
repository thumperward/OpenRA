#region Copyright & License Information
/*
 * Copyright 2007-2017 The OpenRA Developers (see AUTHORS)
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Grant additional conditions when a specified condition has been granted multiple times.")]
	public class StackedConditionInfo : TraitInfo<StackedCondition>
	{
		[FieldLoader.Require]
		[ConsumedConditionReference]
		[Desc("Condition to monitor.")]
		public readonly string Condition = null;

		[FieldLoader.Require]
		[FieldLoader.AllowEmptyEntries]
		[GrantedConditionReference]
		[Desc("Conditions to grant when the monitored condition is granted multiple times.",
			"The first entry is activated at 2x grants, second entry at 3x grants, and so on.",
			"Use empty entries to skip levels.")]
		public readonly string[] StackedConditions = { };
	}

	public class StackedCondition { }
}

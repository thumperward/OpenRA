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

using System;
using System.Collections.Generic;
using System.Linq;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Allows a condition to be granted from an external source (Lua, warheads, etc).")]
	public class ExternalConditionInfo : ITraitInfo, Requires<ConditionManagerInfo>
	{
		[GrantedConditionReference]
		[FieldLoader.Require]
		public readonly string Condition = null;

		[Desc("If > 0, restrict the number of times that this condition can be granted by a single source.")]
		public readonly int SourceCap = 0;

		[Desc("If > 0, restrict the number of times that this condition can be granted by any source.")]
		public readonly int TotalCap = 0;

		public object Create(ActorInitializer init) { return new ExternalCondition(init.Self, this); }
	}

	public class ExternalCondition : ITick
	{
		struct TimedToken
		{
			public readonly int Expires;
			public readonly int Token;
			public readonly object Source;

			public TimedToken(int token, Actor self, object source, int duration)
			{
				Token = token;
				Expires = self.World.WorldTick + duration;
				Source = source;
			}
		}

		public readonly ExternalConditionInfo Info;
		readonly ConditionManager conditionManager;
		readonly Dictionary<object, HashSet<int>> permanentTokens = new Dictionary<object, HashSet<int>>();

		// Tokens are sorted on insert/remove by ascending expiry time
		readonly List<TimedToken> timedTokens = new List<TimedToken>();

		public ExternalCondition(Actor self, ExternalConditionInfo info)
		{
			Info = info;
			conditionManager = self.Trait<ConditionManager>();
		}

		public bool CanGrantCondition(Actor self, object source)
		{
			if (conditionManager == null || source == null)
				return false;

			// Timed tokens do not count towards the source cap: the condition with the shortest
			// remaining duration can always be revoked to make room.
			if (Info.SourceCap > 0)
			{
				HashSet<int> permanentTokensForSource;
				if (permanentTokens.TryGetValue(source, out permanentTokensForSource) && permanentTokensForSource.Count >= Info.SourceCap)
					return false;
			}

			if (Info.TotalCap > 0 && permanentTokens.Values.Sum(t => t.Count) >= Info.TotalCap)
				return false;

			return true;
		}

		public int GrantCondition(Actor self, object source, int duration = 0)
		{
			if (!CanGrantCondition(self, source))
				return ConditionManager.InvalidConditionToken;

			var token = conditionManager.GrantCondition(self, Info.Condition, duration);
			HashSet<int> permanent;
			permanentTokens.TryGetValue(source, out permanent);

			if (duration > 0)
			{
				// Check level caps
				if (Info.SourceCap > 0)
				{
					var timedCount = timedTokens.Count(t => t.Source == source);
					if ((permanent != null ? permanent.Count + timedCount : timedCount) >= Info.SourceCap)
					{
						// Get timed token from the same source with closest expiration.
						var expireIndex = timedTokens.FindIndex(t => t.Source == source);
						if (expireIndex >= 0)
						{
							var expireToken = timedTokens[expireIndex].Token;
							timedTokens.RemoveAt(expireIndex);
							if (conditionManager.TokenValid(self, expireToken))
								conditionManager.RevokeCondition(self, expireToken);
						}
					}
				}

				if (Info.TotalCap > 0)
				{
					var totalCount = permanentTokens.Values.Sum(t => t.Count) + timedTokens.Count;
					if (totalCount >= Info.TotalCap)
					{
						// Prefer tokens from the same source
						if (timedTokens.Count > 0)
						{
							var expire = timedTokens[0].Token;
							if (conditionManager.TokenValid(self, expire))
								conditionManager.RevokeCondition(self, expire);

							timedTokens.RemoveAt(0);
						}
					}
				}

				var timedToken = new TimedToken(token, self, source, duration);
				var index = timedTokens.FindIndex(t => t.Expires >= timedToken.Expires);
				if (index >= 0)
					timedTokens.Insert(index, timedToken);
				else
					timedTokens.Add(timedToken);
			}
			else if (permanent == null)
				permanentTokens.Add(source, new HashSet<int> { token });
			else
				permanent.Add(token);

			return token;
		}

		/// <summary>Revokes the external condition with the given token if it was granted by this trait.</summary>
		/// <returns><c>true</c> if the now-revoked condition was originally granted by this trait.</returns>
		public bool TryRevokeCondition(Actor self, object source, int token)
		{
			if (conditionManager == null || source == null)
				return false;

			HashSet<int> permanentTokensForSource;
			if (permanentTokens.TryGetValue(source, out permanentTokensForSource))
			{
				if (!permanentTokensForSource.Remove(token))
					return false;
			}
			else
			{
				var index = timedTokens.FindIndex(p => p.Token == token);
				if (index >= 0 && timedTokens[index].Source == source)
					timedTokens.RemoveAt(index);
				else
					return false;
			}

			if (conditionManager.TokenValid(self, token))
				conditionManager.RevokeCondition(self, token);

			return true;
		}

		void ITick.Tick(Actor self)
		{
			// Remove expired tokens
			var worldTick = self.World.WorldTick;
			var count = 0;
			while (count < timedTokens.Count && timedTokens[count].Expires < worldTick)
				count++;

			if (count > 0)
				timedTokens.RemoveRange(0, count);
		}
	}
}
